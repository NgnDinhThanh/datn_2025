from bson import ObjectId
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
import logging
from rest_framework.parsers import MultiPartParser, FormParser
import csv
from io import TextIOWrapper
import io
from django.http import HttpResponse
import openpyxl
from openpyxl.utils import get_column_letter

from classes.models import Class
from students.models import Student
from students.serializers import StudentSerializer

# Set up logging
logger = logging.getLogger(__name__)

# Create your views here.
class StudentListCreateView(APIView):
    permission_students = [IsAuthenticated]

    def get(self, request):
        try:
            # Log tất cả student trong database
            all_students = Student.objects.all()
            logger.info(f"All students in database: {[s.student_id for s in all_students]}")
            
            # Lấy danh sách student của teacher
            students = Student.objects.filter(teacher_id=request.user.id)
            serializer = StudentSerializer(students, many=True)
            return Response(serializer.data)
        except Exception as e:
            logger.error(f"Error getting students: {str(e)}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def post(self, request):
        try:
            serializer = StudentSerializer(data=request.data)
            if not serializer.is_valid():
                logger.warning(f"Invalid student data: {serializer.errors}")
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

            # Validate student_id format
            student_id = serializer.validated_data['student_id']
            if not student_id.isalnum():
                logger.warning(f"Invalid student_id format: {student_id}")
                return Response({
                    "error": "Student ID must contain only letters and numbers"
                }, status=status.HTTP_400_BAD_REQUEST)

            if Student.objects(student_id=student_id).first():
                logger.warning(f"Student with ID {student_id} already exists")
                return Response(
                    {"error": "Student with this student_id already exists"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Lấy danh sách class_codes nếu có
            class_codes = request.data.get('class_codes', [])
            valid_class_object_ids = []
            invalid_class_ids = []
            
            for class_id in class_codes:
                try:
                    # Tìm class bằng id (ObjectId)
                    class_obj = Class.objects.get(id=ObjectId(class_id))
                    # Kiểm tra xem class có thuộc về teacher không
                    if class_obj and class_obj.teacher_id == request.user.id:
                        valid_class_object_ids.append(class_obj.id)
                        logger.info(f"Found valid class: {class_obj.class_code}")
                    else:
                        invalid_class_ids.append(str(class_id))
                        logger.warning(f"Class {class_id} does not belong to teacher {request.user.id}")
                except Exception as e:
                    invalid_class_ids.append(str(class_id))
                    logger.error(f"Error finding class {class_id}: {str(e)}")

            # Create new student
            student_obj = Student(
                student_id=serializer.validated_data['student_id'],
                first_name=serializer.validated_data['first_name'],
                last_name=serializer.validated_data['last_name'],
                teacher_id=request.user.id,
                class_codes=valid_class_object_ids
            )
            student_obj.save()
            logger.info(f"Created new student {student_id} for teacher {request.user.id}")

            # Cập nhật chiều ngược lại: thêm student vào student_ids của từng class
            for class_id in valid_class_object_ids:
                try:
                    class_obj = Class.objects.get(id=class_id)
                    if student_obj.id not in class_obj.student_ids:
                        class_obj.student_ids.append(student_obj.id)
                        class_obj.student_count = len(class_obj.student_ids)
                        class_obj.save()
                        logger.info(f"Added student {student_id} to class {class_obj.class_code}")
                except Exception as e:
                    logger.error(f"Error updating class {class_id}: {str(e)}")
                    continue

            # Return response with invalid class IDs if any
            response_data = {
                'student_id': student_obj.student_id,
                'first_name': student_obj.first_name,
                'last_name': student_obj.last_name,
                'teacher_id': str(student_obj.teacher_id),
                'class_codes': [str(id) for id in student_obj.class_codes]
            }
            
            if invalid_class_ids:
                response_data['invalid_class_ids'] = invalid_class_ids
                response_data['message'] = f"Student created with {len(valid_class_object_ids)} classes. {len(invalid_class_ids)} invalid class codes were ignored."

            return Response(response_data, status=status.HTTP_201_CREATED)
        except Exception as e:
            logger.error(f"Error creating student: {str(e)}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class StudentDetailView(APIView):
    permission_students = [IsAuthenticated]
    def get_object(self, student_id):
        try:
            student = Student.objects.get(student_id=student_id)
            logger.debug(f"Found student {student_id}")
            return student
        except Student.DoesNotExist:
            logger.warning(f"Student {student_id} not found")
            return None
        except Exception as e:
            logger.error(f"Error retrieving student {student_id}: {str(e)}")
            return None

    def get(self, request, student_id):
        try:
            student_obj = self.get_object(student_id)
            if not student_obj:
                return Response(
                    {'error': 'Student not found'},
                    status=status.HTTP_404_NOT_FOUND
                )

            if not (request.user.is_teacher and request.user.id == student_obj.teacher_id):
                logger.warning(f"User {request.user.id} attempted to access student {student_id} without permission")
                return Response(
                    {"error": "You don't have permission to view this student"},
                    status=status.HTTP_403_FORBIDDEN
                )

            return Response({
                "student_id": student_obj.student_id,
                "first_name": student_obj.first_name,
                "last_name": student_obj.last_name,
                "teacher_id": str(student_obj.teacher_id),
                "class_codes": [str(id) for id in student_obj.class_codes]
            })
        except Exception as e:
            logger.error(f"Error retrieving student details: {str(e)}")
            return Response(
                {'error': "Failed to retrieve student details"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def put(self, request, student_id):
        try:
            logger.info(f"Attempting to find student with student_id: {student_id}")
            try:
                student = Student.objects.get(student_id=student_id)
                logger.info(f"Found student: {student.student_id}")
            except Student.DoesNotExist:
                logger.error(f"Student with student_id {student_id} not found")
                return Response(
                    {"error": f"Student with ID {student_id} not found"},
                    status=status.HTTP_404_NOT_FOUND
                )
            except Exception as e:
                logger.error(f"Error finding student: {str(e)}")
                return Response(
                    {"error": str(e)},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )

            if student.teacher_id != request.user.id:
                logger.warning(f"User {request.user.id} attempted to update student {student_id} without permission")
                return Response(
                    {"error": "You don't have permission to update this student"},
                    status=status.HTTP_403_FORBIDDEN
                )

            # Lấy danh sách class_codes mới từ request
            new_class_codes = []
            invalid_class_codes = []
            for class_id in request.data.get('class_codes', []):
                try:
                    class_obj = Class.objects.get(id=ObjectId(class_id))
                    if class_obj.teacher_id == request.user.id:
                        new_class_codes.append(class_obj.id)
                        logger.info(f"Found valid class: {class_obj.class_code}")
                    else:
                        invalid_class_codes.append(str(class_id))
                        logger.warning(f"Class {class_id} does not belong to teacher {request.user.id}")
                except Exception as e:
                    invalid_class_codes.append(str(class_id))
                    logger.error(f"Error finding class {class_id}: {str(e)}")

            old_class_codes = set(student.class_codes)
            new_class_codes_set = set(new_class_codes)

            # Xóa student khỏi các class cũ không còn trong class_codes mới
            for class_id in old_class_codes - new_class_codes_set:
                try:
                    class_obj = Class.objects.get(id=class_id)
                    if student.id in class_obj.student_ids:
                        class_obj.student_ids.remove(student.id)
                        class_obj.student_count = len(class_obj.student_ids)
                        class_obj.save()
                        logger.info(f"Removed student {student.student_id} from class {class_obj.class_code}")
                except Exception as e:
                    logger.error(f"Error removing student from class {class_id}: {str(e)}")

            # Thêm student vào các class mới
            for class_id in new_class_codes_set - old_class_codes:
                try:
                    class_obj = Class.objects.get(id=class_id)
                    if student.id not in class_obj.student_ids:
                        class_obj.student_ids.append(student.id)
                        class_obj.student_count = len(class_obj.student_ids)
                        class_obj.save()
                        logger.info(f"Added student {student.student_id} to class {class_obj.class_code}")
                except Exception as e:
                    logger.error(f"Error adding student to class {class_id}: {str(e)}")

            # Cập nhật thông tin student
            if 'first_name' in request.data:
                student.first_name = request.data['first_name']
            if 'last_name' in request.data:
                student.last_name = request.data['last_name']
            if 'class_codes' in request.data:
                student.class_codes = list(new_class_codes_set)
                logger.info(f"Updated class_codes: {student.class_codes}")
            student.save()
            logger.info(f"Updated student {student.student_id}")

            serializer = StudentSerializer(student)
            response_data = serializer.data
            if invalid_class_codes:
                response_data['invalid_class_codes'] = invalid_class_codes
                response_data['message'] = f"Updated with {len(new_class_codes_set)} classes. {len(invalid_class_codes)} invalid class codes were ignored."
            return Response(response_data)
        except Exception as e:
            logger.error(f"Error updating student: {str(e)}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def delete(self, request, student_id):
        try:
            student_obj = self.get_object(student_id)
            if not student_obj:
                return Response(
                    {"error": "Student not found"},
                    status=status.HTTP_404_NOT_FOUND
                )

            if not (request.user.is_teacher and request.user.id == student_obj.teacher_id):
                logger.warning(f"User {request.user.id} attempted to delete student {student_id} without permission")
                return Response(
                    {"error": "Only the teacher can delete this student"},
                    status=status.HTTP_403_FORBIDDEN
                )

            # Remove student from all classes
            for class_id in student_obj.class_codes:
                try:
                    class_obj = Class.objects.get(id=class_id)
                    if student_obj.id in class_obj.student_ids:
                        class_obj.student_ids.remove(student_obj.id)
                        class_obj.student_count = len(class_obj.student_ids)
                        class_obj.save()
                        logger.debug(f"Removed student {student_id} from class {class_id}")
                except Class.DoesNotExist:
                    logger.warning(f"Class {class_id} not found when removing student {student_id}")
                except Exception as e:
                    logger.error(f"Error removing student from class {class_id}: {str(e)}")
            student_obj.delete()
            logger.info(f"Deleted student {student_id}")
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Exception as e:
            logger.error(f"Error deleting student {student_id}: {str(e)}")
            return Response(
                {'error': "Failed to delete student"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class StudentImportView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        # Nếu có students (JSON) thì import từ JSON, không cần file
        students_json = request.data.get('students')
        class_id = request.data.get('class_id')
        if students_json:
            import json
            try:
                students = json.loads(students_json)
            except Exception as e:
                return Response({'error': f'Invalid students data: {str(e)}'}, status=400)
            success_count = 0
            error_count = 0
            error_rows = []
            from students.models import Student
            from classes.models import Class
            for idx, s in enumerate(students, start=1):
                try:
                    student_id = s.get('student_id', '').strip()
                    first_name = s.get('first_name', '').strip()
                    last_name = s.get('last_name', '').strip()
                    if not student_id or not first_name or not last_name:
                        raise Exception('Student ID, First Name, Last Name are required')
                    # Kiểm tra trùng student_id
                    if Student.objects(student_id=student_id).first():
                        raise Exception('Student ID already exists')
                    student = Student(
                        student_id=student_id,
                        first_name=first_name,
                        last_name=last_name,
                        teacher_id=request.user.id,
                        class_codes=[class_id] if class_id else []
                    )
                    student.save()
                    # Thêm vào class nếu có
                    if class_id:
                        class_obj = Class.objects(id=class_id, teacher_id=request.user.id).first()
                        if class_obj and student.id not in class_obj.student_ids:
                            class_obj.student_ids.append(student.id)
                            class_obj.student_count = len(class_obj.student_ids)
                            class_obj.save()
                    success_count += 1
                except Exception as e:
                    error_count += 1
                    error_rows.append({'row': idx, 'error': str(e), 'data': s})
            return Response({
                'success_count': success_count,
                'error_count': error_count,
                'errors': error_rows
            })
        # Nếu không có students, fallback về logic cũ nhận file
        file = request.FILES.get('file')
        has_header = request.data.get('has_header', 'false').lower() == 'true'
        if not file:
            return Response({'error': 'No file uploaded'}, status=400)
        results = []
        success_count = 0
        error_count = 0
        error_rows = []
        try:
            csvfile = TextIOWrapper(file, encoding='utf-8')
            reader = csv.reader(csvfile)
            if has_header:
                next(reader, None)
            for idx, row in enumerate(reader, start=1):
                try:
                    # Giả định thứ tự: first_name, last_name, student_id, external_ref, class_name
                    first_name = row[0].strip() if len(row) > 0 else ''
                    last_name = row[1].strip() if len(row) > 1 else ''
                    student_id = row[2].strip() if len(row) > 2 else ''
                    external_ref = row[3].strip() if len(row) > 3 else ''
                    class_name = row[4].strip() if len(row) > 4 else ''
                    if not first_name or not last_name:
                        raise Exception('First name and last name are required')
                    # Tìm hoặc tạo class nếu có class_name
                    class_obj = None
                    if class_name:
                        from classes.models import Class
                        class_obj = Class.objects(class_name=class_name, teacher_id=request.user.id).first()
                        if not class_obj:
                            class_obj = Class(class_code=class_name.lower().replace(' ', ''), class_name=class_name, teacher_id=request.user.id)
                            class_obj.save()
                    # Nếu không có student_id thì tự sinh
                    if not student_id:
                        import random
                        student_id = str(random.randint(100000, 999999))
                    # Tạo student
                    from students.models import Student
                    student = Student.objects(student_id=student_id).first()
                    if student:
                        raise Exception('Student ID already exists')
                    student = Student(
                        student_id=student_id,
                        first_name=first_name,
                        last_name=last_name,
                        teacher_id=request.user.id,
                        class_codes=[class_obj.id] if class_obj else []
                    )
                    student.save()
                    # Thêm student vào class nếu có
                    if class_obj:
                        if student.id not in class_obj.student_ids:
                            class_obj.student_ids.append(student.id)
                            class_obj.student_count = len(class_obj.student_ids)
                            class_obj.save()
                    success_count += 1
                except Exception as e:
                    error_count += 1
                    error_rows.append({'row': idx, 'error': str(e), 'data': row})
            return Response({
                'success_count': success_count,
                'error_count': error_count,
                'errors': error_rows
            })
        except Exception as e:
            return Response({'error': str(e)}, status=500)

class StudentExportCSVView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        students = Student.objects.filter(teacher_id=request.user.id)
        from classes.models import Class
        response = HttpResponse(content_type='text/csv; charset=utf-8')
        response['Content-Disposition'] = 'attachment; filename=students.csv'
        writer = csv.writer(response)
        writer.writerow(['Student ID', 'First Name', 'Last Name', 'Class'])
        for s in students:
            class_names = []
            for cid in s.class_codes:
                class_obj = Class.objects(id=cid).first()
                if class_obj:
                    class_names.append(class_obj.class_name)
            writer.writerow([
                s.student_id, s.first_name, s.last_name, ', '.join(class_names)
            ])
        return response

class StudentExportExcelView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        students = Student.objects.filter(teacher_id=request.user.id)
        from classes.models import Class
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.append(['Student ID', 'First Name', 'Last Name', 'Class'])
        for s in students:
            class_names = []
            for cid in s.class_codes:
                class_obj = Class.objects(id=cid).first()
                if class_obj:
                    class_names.append(class_obj.class_name)
            ws.append([
                s.student_id, s.first_name, s.last_name, ', '.join(class_names)
            ])
        output = io.BytesIO()
        wb.save(output)
        output.seek(0)
        response = HttpResponse(output, content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        response['Content-Disposition'] = 'attachment; filename=students.xlsx'
        return response
