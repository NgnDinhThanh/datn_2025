from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import api_view
from classes.models import Class
from classes.serializer import ClassSerializer
from exams.models import Exam
from students.models import Student
from users.models import User
import logging
import traceback
import json
import sys
from bson import ObjectId
import os

# Set up file logging
log_file = 'debug.log'
logging.basicConfig(
    filename=log_file,
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@api_view(['GET'])
def test_mongo(request):
    """Simple test endpoint to check MongoDB connection"""
    try:
        # Log to file
        with open(log_file, 'a') as f:
            f.write("\n=== Starting MongoDB Test ===\n")
        
        # Test 1: Just try to connect
        logger.debug("Attempting to connect to MongoDB...")
        with open(log_file, 'a') as f:
            f.write("Attempting to connect to MongoDB...\n")
        
        # Test 2: Try to create a simple document
        test_class = Class(
            class_code="TEST001",
            class_name="Test Class",
            teacher_id=request.user.id  # Use the logged-in user's ID
        )
        logger.debug("Created test class object")
        with open(log_file, 'a') as f:
            f.write("Created test class object\n")
        
        # Test 3: Try to save
        test_class.save()
        logger.debug("Successfully saved test class")
        with open(log_file, 'a') as f:
            f.write("Successfully saved test class\n")
        
        # Test 4: Try to query
        saved_class = Class.objects(class_code="TEST001").first()
        logger.debug(f"Successfully queried test class: {saved_class.class_code}")
        with open(log_file, 'a') as f:
            f.write(f"Successfully queried test class: {saved_class.class_code}\n")
        
        # Test 5: Try to delete
        test_class.delete()
        logger.debug("Successfully deleted test class")
        with open(log_file, 'a') as f:
            f.write("Successfully deleted test class\n")
        
        return Response({
            "status": "success",
            "message": "All MongoDB operations successful"
        })
    except Exception as e:
        error_msg = f"Error in test_mongo: {str(e)}\n{traceback.format_exc()}"
        logger.error(error_msg)
        with open(log_file, 'a') as f:
            f.write(f"\nERROR: {error_msg}\n")
        
        return Response({
            "status": "error",
            "error": str(e),
            "detail": error_msg
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class ClassListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            # Get classes based on user role
            if request.user.is_teacher:
                classes = Class.objects(teacher_id=request.user.id)
            else:
                classes = Class.objects(student_ids=request.user.id)

            # Convert to list of dicts
            class_list = []
            for class_obj in classes:
                class_list.append({
                    'id': str(class_obj.id),
                    'class_code': class_obj.class_code,
                    'class_name': class_obj.class_name,
                    'student_count': class_obj.student_count,
                    'teacher_id': str(class_obj.teacher_id),  # Convert ObjectId to string
                    'student_ids': [str(id) for id in class_obj.student_ids],  # Convert ObjectIds to strings
                    'exam_ids': [str(id) for id in class_obj.exam_ids]
                })

            return Response(class_list)

        except Exception as e:
            logger.error(f"Error in get classes: {str(e)}")
            return Response(
                {"error": "Failed to retrieve classes"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def post(self, request):
        try:
            # Validate request data
            serializer = ClassSerializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

            # Check if class_code already exists
            if Class.objects(class_code=serializer.validated_data['class_code']).first():
                return Response(
                    {"error": "Class code already exists"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Lấy danh sách student_ids nếu có
            student_ids = request.data.get('student_ids', [])
            valid_student_object_ids = []
            invalid_student_ids = []
            
            # Tìm và xác thực student_ids
            for student_id in student_ids:
                try:
                    student = None
                    try:
                        # Thử tìm bằng ObjectId
                        student = Student.objects.get(id=ObjectId(student_id))
                    except Exception:
                        # Thử tìm bằng student_id
                        student = Student.objects.get(student_id=str(student_id))
                    
                    if student:
                        valid_student_object_ids.append(student.id)
                except Exception:
                    invalid_student_ids.append(str(student_id))

            # Create new class
            class_obj = Class(
                class_code=serializer.validated_data['class_code'],
                class_name=serializer.validated_data['class_name'],
                teacher_id=request.user.id,  # Sử dụng trực tiếp ObjectId
                student_ids=valid_student_object_ids,
                student_count=len(valid_student_object_ids)
            )

            # Save to database
            class_obj.save()

            # Cập nhật chiều ngược lại: thêm class vào class_codes của từng student
            for student_id in valid_student_object_ids:
                try:
                    student = Student.objects.get(id=student_id)
                    # Log để debug
                    logger.info(f"Current teacher_id: {request.user.id}, Student teacher_id: {student.teacher_id}")
                    # Kiểm tra xem student có cùng teacher với class không
                    if student.teacher_id == request.user.id:
                        if class_obj.id not in student.class_codes:
                            student.class_codes.append(class_obj.id)
                            student.save()
                            logger.info(f"Added class {class_obj.class_code} to student {student.student_id}")
                    else:
                        logger.warning(f"Student {student.student_id} belongs to different teacher")
                except Exception as e:
                    logger.error(f"Error updating student {student_id}: {str(e)}")
                    continue

            # Return response with invalid student IDs if any
            response_data = {
                'class_code': class_obj.class_code,
                'class_name': class_obj.class_name,
                'student_count': class_obj.student_count,
                'teacher_id': str(class_obj.teacher_id),
                'student_ids': [str(id) for id in class_obj.student_ids],
                'exam_ids': [str(id) for id in class_obj.exam_ids]
            }
            
            if invalid_student_ids:
                response_data['invalid_student_ids'] = invalid_student_ids
                response_data['message'] = f"Class created with {len(valid_student_object_ids)} students. {len(invalid_student_ids)} invalid student IDs were ignored."

            return Response(response_data, status=status.HTTP_201_CREATED)

        except Exception as e:
            logger.error(f"Error in create class: {str(e)}")
            return Response({
                "error": "Failed to create class",
                "detail": str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class ClassDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, class_code):
        try:
            return Class.objects.get(class_code=class_code)
        except Class.DoesNotExist:
            return None

    def get(self, request, class_code):
        try:
            class_obj = self.get_object(class_code)
            if not class_obj:
                return Response(
                    {"error": "Class not found"},
                    status=status.HTTP_404_NOT_FOUND
                )

            # Check permissions
            if not (request.user.is_teacher and request.user.id == class_obj.teacher_id or
                    request.user.id in class_obj.student_ids):
                return Response(
                    {"error": "You don't have permission to view this class"},
                    status=status.HTTP_403_FORBIDDEN
                )

            return Response({
                'class_code': class_obj.class_code,
                'class_name': class_obj.class_name,
                'student_count': class_obj.student_count,
                'teacher_id': str(class_obj.teacher_id),  # Convert ObjectId to string
                'student_ids': [str(id) for id in class_obj.student_ids],  # Convert ObjectIds to strings
                'exam_ids': [str(id) for id in class_obj.exam_ids]
            })

        except Exception as e:
            logger.error(f"Error in get class detail: {str(e)}")
            return Response(
                {"error": "Failed to retrieve class details"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def put(self, request, class_code):
        try:
            class_obj = Class.objects.get(class_code=class_code)
            if class_obj.teacher_id != request.user.id:
                return Response(
                    {"error": "You don't have permission to update this class"},
                    status=status.HTTP_403_FORBIDDEN
                )

            # Chỉ cập nhật danh sách sinh viên nếu thực sự có trường student_ids trong payload
            if 'student_ids' in request.data:
                # Lấy danh sách student_ids mới từ request và chuyển đổi thành ObjectId
                new_student_ids = []
                invalid_student_ids = []
                for student_id in request.data.get('student_ids', []):
                    try:
                        # Thử tìm student bằng ObjectId
                        try:
                            student = Student.objects.get(id=ObjectId(student_id))
                            new_student_ids.append(student.id)
                        except Exception:
                            # Thử tìm student bằng student_id
                            student = Student.objects.get(student_id=str(student_id))
                            new_student_ids.append(student.id)
                    except Exception:
                        invalid_student_ids.append(str(student_id))

                old_student_ids = class_obj.student_ids

                # Chỉ thêm các student mới (chưa có trong old_student_ids)
                students_to_add = set(new_student_ids) - set(old_student_ids)
                for student_id in students_to_add:
                    try:
                        student = Student.objects.get(id=student_id)
                        if student.teacher_id == request.user.id:  # Kiểm tra student có thuộc về teacher không
                            if class_obj.id not in student.class_codes:
                                student.class_codes.append(class_obj.id)
                                student.save()
                                logger.info(f"Added class {class_obj.class_code} to student {student.student_id}")
                    except Exception as e:
                        logger.error(f"Error adding student to class {student_id}: {str(e)}")

                # Xóa class_id khỏi class_codes của các student bị loại khỏi lớp
                students_to_remove = set(old_student_ids) - set(new_student_ids)
                for student_id in students_to_remove:
                    try:
                        student = Student.objects.get(id=student_id)
                        if class_obj.id in student.class_codes:
                            student.class_codes.remove(class_obj.id)
                            student.save()
                            logger.info(f"Removed class {class_obj.class_code} from student {student.student_id}")
                    except Exception as e:
                        logger.error(f"Error removing class from student {student_id}: {str(e)}")

                # Gán mới hoàn toàn danh sách student_ids và cập nhật student_count
                class_obj.student_ids = new_student_ids
                class_obj.student_count = len(new_student_ids)

            # Cập nhật thông tin class
            if 'class_name' in request.data:
                class_obj.class_name = request.data['class_name']
                # Cập nhật lại class_codes của sinh viên trong lớp này
                for student_id in class_obj.student_ids:
                    student = Student.objects.get(id=student_id)
                    if class_obj.id in student.class_codes:
                        student.save()  # Lưu lại để cập nhật thông tin lớp học

            class_obj.save()
            logger.info(f"Updated class {class_obj.class_code}")

            # Serialize để trả về response
            serializer = ClassSerializer(class_obj)
            response_data = serializer.data
            
            # Thêm thông tin về các student_id không hợp lệ nếu có
            if 'student_ids' in request.data and invalid_student_ids:
                response_data['invalid_student_ids'] = invalid_student_ids
                response_data['message'] = f"Added {len(students_to_add)} new students. {len(invalid_student_ids)} invalid student IDs were ignored."
            
            return Response(response_data)
        except Exception as e:
            logger.error(f"Error updating class: {str(e)}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def delete(self, request, class_code):
        try:
            class_obj = self.get_object(class_code)
            if not class_obj:
                return Response(
                    {"error": "Class not found"},
                    status=status.HTTP_404_NOT_FOUND
                )

            # Check if user is the teacher
            if not (request.user.is_teacher and request.user.id == class_obj.teacher_id):
                return Response(
                    {"error": "Only the teacher can delete this class"},
                    status=status.HTTP_403_FORBIDDEN
                )

            # Bổ sung: Xóa class_id khỏi class_codes của từng student
            for student_id in class_obj.student_ids:
                student = Student.objects(id=student_id).first()
                if student and class_obj.id in student.class_codes:
                    student.class_codes.remove(class_obj.id)
                    student.save()

            # for exam_id in class_obj.exam_ids:
            #     exam = Exam.objects(id = exam_id).first()
            #     if exam and class_obj.id in exam.class_codes:
            #         exam.class_codes.remove(class_obj.id)
            #         exam.save()

            class_obj.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)

        except Exception as e:
            logger.error(f"Error in delete class: {str(e)}")
            return Response(
                {"error": "Failed to delete class"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )