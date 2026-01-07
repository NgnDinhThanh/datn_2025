# Create your views here.
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
import tempfile
import os
import json
import logging
from datetime import datetime
from django.conf import settings

from grading.models import Grade
from grading.serializers import GradeSerializer
from grading.services.scanning_service import (
    scan_and_grade,
    preview_check,
    get_answer_key_for_version,
    grade_answers_with_key,
)
from exams.models import Exam as Quiz
from answer_sheets.models import AnswerSheetTemplate
from answer_keys.models import AnswerKey

logger = logging.getLogger(__name__)


class GradeListView(APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        """
        Get grades with optional filters
        Query params: quiz_id, student_id, class_code
        """
        quiz_id = request.query_params.get('quiz_id')
        student_id = request.query_params.get('student_id')
        class_code = request.query_params.get('class_code')
        teacher_id = str(request.user.id)
        
        # Filter by teacher
        grades = Grade.objects(teacher_id=teacher_id)
        
        # Apply filters
        if quiz_id:
            grades = grades.filter(exam_id=quiz_id)
        if student_id:
            grades = grades.filter(student_id=student_id)
        if class_code:
            grades = grades.filter(class_code=class_code)
        
        # Order by scanned_at descending
        grades = grades.order_by('-scanned_at')
        
        serializer = GradeSerializer(grades, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = GradeSerializer(data=request.data)
        if serializer.is_valid():
            grade_obj = Grade(**serializer.validated_data)
            grade_obj.save()
            return Response(GradeSerializer(grade_obj).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class GradeDetailView(APIView):
    def get_object(self, id):
        return Grade.objects(id=id).first()

    def get(self, request, id):
        grade_obj = self.get_object(id)
        if not grade_obj:
            return Response({'error': 'Not found'}, status=404)
        serializer = GradeSerializer(grade_obj)
        return Response(serializer.data)

    def put(self, request, id):
        grade_obj = self.get_object(id)
        if not grade_obj:
            return Response({'error': 'Not found'}, status=404)
        serializer = GradeSerializer(grade_obj, data=request.data)
        if serializer.is_valid():
            for attr, value in serializer.validated_data.items():
                setattr(grade_obj, attr, value)
            grade_obj.save()
            return Response(GradeSerializer(grade_obj).data)
        return Response(serializer.errors, status=400)

    def delete(self, request, id):
        grade_obj = self.get_object(id)
        if not grade_obj:
            return Response({'error': 'Not found'}, status=404)
        grade_obj.delete()
        return Response(status=204)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def scan_answer_sheet(request):
    """
    Scan and grade answer sheet
    POST /api/grading/scan/
    """
    try:
        # 1. Validate input
        if 'image' not in request.FILES:
            return Response({'error': 'No image provided'}, status=400)
        if 'quiz_id' not in request.data:
            return Response({'error': 'No quiz_id provided'}, status=400)
        if 'answersheet_id' not in request.data:
            return Response({'error': 'No answersheet_id provided'}, status=400)
        
        image_file = request.FILES['image']
        quiz_id = request.data['quiz_id']
        answersheet_id = request.data['answersheet_id']
        teacher_id = str(request.user.id)
        
        # 2. Check image size
        grading_config = getattr(settings, 'GRADING_CONFIG', {})
        max_size_mb = grading_config.get('MAX_IMAGE_SIZE_MB', 10)
        image_size_mb = image_file.size / (1024 * 1024)
        
        if image_size_mb > max_size_mb:
            return Response({
                'error': f'Image size too large. Max size: {max_size_mb}MB. Current: {image_size_mb:.2f}MB'
            }, status=400)
        
        # 3. Save temporary image
        with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as temp_file:
            for chunk in image_file.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name
        
        try:
            # 4. Process image
            result = scan_and_grade(
                image_path=temp_path,
                quiz_id=quiz_id,
                answersheet_id=answersheet_id,
                teacher_id=teacher_id
            )
            
            if not result.get('success'):
                return Response({
                    'error': result.get('error', 'Processing failed')
                }, status=400)
            
            # 5. Return result
            return Response(result)
            
        finally:
            # Clean up temp file
            if os.path.exists(temp_path):
                try:
                    os.unlink(temp_path)
                except Exception as e:
                    logger.warning(f"Failed to delete temp file: {e}")
                
    except Exception as e:
        logger.error(f"Error scanning answer sheet: {str(e)}")
        return Response({
            'error': f'Internal server error: {str(e)}'
        }, status=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_template_json_api(request):
    """
    Get template JSON content for an answer sheet
    GET /api/grading/template-json/?answersheet_id=xxx
    """
    try:
        answersheet_id = request.query_params.get('answersheet_id')
        if not answersheet_id:
            return Response({'error': 'answersheet_id is required'}, status=400)

        teacher_id = str(request.user.id)

        try:
            template = AnswerSheetTemplate.objects.get(id=answersheet_id)
        except AnswerSheetTemplate.DoesNotExist:
            return Response(
                {'error': f'Answer sheet template with id {answersheet_id} not found'},
                status=404,
            )

        # Permission check: template must belong to current teacher
        if str(template.teacher_id) != teacher_id:
            return Response(
                {'error': 'You do not have permission to access this answer sheet template'},
                status=403,
            )

        if not template.file_json or not os.path.exists(template.file_json):
            return Response(
                {'error': f'Template JSON file not found: {template.file_json}'},
                status=404,
            )

        # Load JSON file and return content
        with open(template.file_json, 'r', encoding='utf-8') as f:
            data = json.load(f)

        return Response({'success': True, 'template': data})

    except Exception as e:
        logger.error(f"Error getting template JSON: {str(e)}", exc_info=True)
        return Response(
            {'error': f'Internal server error: {str(e)}'},
            status=500,
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def grade_from_json_api(request):
    """
    Grade answer sheet from JSON data (client-side scanning)
    POST /api/grading/grade-from-json/

    Expected JSON body:
    {
        "quiz_id": "...",            # required
        "answersheet_id": "...",     # optional (for consistency)
        "student_id": "123456",      # optional
        "version_code": "001",       # required for now
        "class_id": "10A1",          # optional
        "answers": {                 # required
            "1": "A",
            "2": 1,
            "3": [0]
        },
        "total_questions": 50,       # optional
        "metadata": {...},           # ignored by server for now
        "images": {
            "warped_image_base64": null,
            "annotated_image_base64": null
        }
    }
    """
    try:
        data = request.data

        # Required fields
        quiz_id = data.get('quiz_id')
        answers = data.get('answers')
        version_code = data.get('version_code')

        if not quiz_id:
            return Response({'error': 'quiz_id is required'}, status=400)
        if answers is None:
            return Response({'error': 'answers is required'}, status=400)
        if not version_code:
            return Response({'error': 'version_code is required'}, status=400)

        teacher_id = str(request.user.id)

        # Load AnswerKey and check permission (same as scan_and_grade)
        try:
            answer_key_obj = AnswerKey.objects.get(
                quiz_id=quiz_id,
                id_teacher=str(teacher_id)
            )
        except AnswerKey.DoesNotExist:
            return Response({
                'success': False,
                'error': f'Answer key not found for quiz {quiz_id}',
            }, status=404)

        # Build answer key dict for this version
        answer_key_dict = get_answer_key_for_version(answer_key_obj, version_code)
        if answer_key_dict is None:
            return Response({
                'success': False,
                'error': f'Version code {version_code} not found in answer key',
            }, status=400)

        # Parse answers (can be dict or JSON string)
        import json as _json
        if isinstance(answers, str):
            try:
                answers = _json.loads(answers)
            except _json.JSONDecodeError as e:
                return Response({
                    'success': False,
                    'error': f'Invalid answers JSON: {str(e)}',
                }, status=400)

        if not isinstance(answers, dict):
            return Response({
                'success': False,
                'error': 'answers must be a dictionary',
            }, status=400)

        # Determine total questions (optional override from client)
        total_questions_client = data.get('total_questions')
        try:
            if total_questions_client is not None:
                total_questions_client = int(total_questions_client)
        except (TypeError, ValueError):
            total_questions_client = None

        # Grade
        score, total_questions, percentage = grade_answers_with_key(
            answer_key_dict=answer_key_dict,
            student_answers=answers,
            num_questions=total_questions_client,
        )

        # Other optional fields
        student_id = data.get('student_id') or ''
        class_id = data.get('class_id')
        answersheet_id = data.get('answersheet_id')

        # Convert answer_key_dict to client-friendly format
        # answer_key_dict: {0: 2, 1: 0, ...} (0-based question index: answer index)
        # Convert to: {"1": 2, "2": 0, ...} (1-based question key: answer index)
        correct_answers = {}
        for q_idx, ans_idx in answer_key_dict.items():
            correct_answers[str(q_idx + 1)] = ans_idx

        # For now we don't re-annotate image on server when grading from JSON.
        annotated_image_base64 = None

        result = {
            'success': True,
            'score': score,
            'total_questions': total_questions,
            'percentage': percentage,
            'student_id': student_id,
            'quiz_id': quiz_id,
            'class_id': class_id,
            'answers': answers,
            'correct_answers': correct_answers,  # Answer key for client to draw annotated image
            'version_code': version_code,
            'annotated_image_base64': annotated_image_base64,
        }

        return Response(result)

    except Exception as e:
        logger.error(f"Error grading from JSON: {str(e)}", exc_info=True)
        return Response({
            'success': False,
            'error': f'Internal server error: {str(e)}',
        }, status=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def preview_check_api(request):
    """
    Preview check for ArUco markers
    POST /api/grading/preview-check/
    """
    try:
        if 'image' not in request.FILES:
            return Response({'error': 'No image file provided'}, status=400)
        
        image_file = request.FILES['image']
        
        # Save temporary image
        with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as temp_file:
            for chunk in image_file.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name
        
        try:
            # Check markers
            result = preview_check(temp_path)
            return Response(result)
        finally:
            # Clean up temp file
            if os.path.exists(temp_path):
                try:
                    os.unlink(temp_path)
                except Exception as e:
                    logger.warning(f"Failed to delete temp file: {e}")
                
    except Exception as e:
        logger.error(f"Error in preview check: {str(e)}")
        return Response({'error': str(e)}, status=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def save_grade_api(request):
    """
    Save grade to database
    POST /api/grading/save-grade/
    """
    try:
        # Validate input
        required_fields = ['quiz_id', 'student_id', 'score', 'percentage', 'answers']
        for field in required_fields:
            if field not in request.data:
                return Response({
                    'error': f'Missing required field: {field}'
                }, status=400)
        
        quiz_id = request.data['quiz_id']
        student_id = request.data['student_id']
        score = float(request.data['score'])
        percentage = float(request.data['percentage'])
        
        # Parse answers - có thể là JSON string hoặc dict
        answers_data = request.data['answers']
        if isinstance(answers_data, str):
            # Nếu là string, parse JSON
            try:
                answers = json.loads(answers_data)
            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON in answers: {e}")
                return Response({
                    'error': f'Invalid answers format: {str(e)}'
                }, status=400)
        elif isinstance(answers_data, dict):
            # Nếu đã là dict, dùng trực tiếp
            answers = answers_data
        else:
            logger.error(f"Invalid answers type: {type(answers_data)}")
            return Response({
                'error': 'Invalid answers format: must be dict or JSON string'
            }, status=400)
        
        # Validate answers là dict
        if not isinstance(answers, dict):
            return Response({
                'error': 'Answers must be a dictionary'
            }, status=400)
        
        class_id = request.data.get('class_id')
        version_code = request.data.get('version_code')
        answersheet_id = request.data.get('answersheet_id')
        teacher_id = str(request.user.id)
        
        # Validate Quiz exists
        try:
            quiz = Quiz.objects.get(id=quiz_id)
        except Quiz.DoesNotExist:
            return Response({
                'error': f'Quiz with id {quiz_id} not found'
            }, status=404)
        
        # Validate teacher has permission
        if str(quiz.teacher_id) != teacher_id:
            return Response({
                'error': 'You do not have permission to access this quiz'
            }, status=403)
        
        # Get class_code from class_id if provided
        # Note: class_id from scanning result is actually class_code (string), not ObjectId
        class_code = None
        if class_id:
            from classes.models import Class
            from bson import ObjectId
            
            # Try to determine if class_id is ObjectId or class_code
            # If it's a valid ObjectId format (24 hex chars), try query by id
            # Otherwise, treat it as class_code
            is_objectid_format = False
            try:
                if len(class_id) == 24:
                    # Try to parse as ObjectId
                    ObjectId(class_id)
                    is_objectid_format = True
            except:
                pass
            
            try:
                if is_objectid_format:
                    # Query by ObjectId
                    class_obj = Class.objects.get(id=class_id)
                    class_code = class_obj.class_code
                else:
                    # Query by class_code (most common case from scanning)
                    class_obj = Class.objects.get(class_code=class_id)
                    class_code = class_obj.class_code
            except Class.DoesNotExist:
                logger.warning(f"Class not found with id/code: {class_id}")
                # Continue without class_code - will try to get from quiz
        
        # If class_code not provided, try to get from quiz
        if not class_code and quiz.class_codes:
            class_code = quiz.class_codes[0]  # Use first class code
        
        if not class_code:
            return Response({
                'error': 'Class code is required'
            }, status=400)
        
        # Handle image uploads (optional)
        scanned_image_path = None
        annotated_image_path = None
        
        grading_config = getattr(settings, 'GRADING_CONFIG', {})
        scanned_image_dir = grading_config.get('SCANNED_IMAGE_DIR')
        annotated_image_dir = grading_config.get('ANNOTATED_IMAGE_DIR')
        
        # Save scanned image if provided
        if 'scanned_image' in request.FILES and scanned_image_dir:
            scanned_image_file = request.FILES['scanned_image']
            os.makedirs(scanned_image_dir, exist_ok=True)
            # Generate unique filename
            import uuid
            filename = f"{uuid.uuid4()}_scanned.jpg"
            scanned_image_path = os.path.join(scanned_image_dir, filename)
            with open(scanned_image_path, 'wb') as f:
                for chunk in scanned_image_file.chunks():
                    f.write(chunk)
            scanned_image_path = f"/media/grading/scanned_images/{filename}"
        
        # Save annotated image if provided
        if 'annotated_image' in request.FILES and annotated_image_dir:
            annotated_image_file = request.FILES['annotated_image']
            os.makedirs(annotated_image_dir, exist_ok=True)
            # Generate unique filename
            import uuid
            filename = f"{uuid.uuid4()}_annotated.jpg"
            annotated_image_path = os.path.join(annotated_image_dir, filename)
            with open(annotated_image_path, 'wb') as f:
                for chunk in annotated_image_file.chunks():
                    f.write(chunk)
            annotated_image_path = f"/media/grading/annotated_images/{filename}"
        
        # Create new Grade record (allow duplicates - like ZipGrade)
        from bson import ObjectId
        
        # Always create new grade (no duplicate check)
        # Users can delete duplicates later if needed
        grade = Grade(
            exam_id=quiz_id,
            student_id=student_id,
            class_code=class_code,
            score=score,
            percentage=percentage,
            answers=answers,
            teacher_id=ObjectId(teacher_id),
            version_code=version_code or '',
            answersheet_id=answersheet_id or '',
            scanned_image=scanned_image_path or '',
            annotated_image=annotated_image_path or '',
            scanned_at=datetime.now()
        )
        grade.save()
        
        # Return result
        serializer = GradeSerializer(grade)
        return Response({
            'success': True,
            'grade_id': str(grade.id),
            'grade': serializer.data
        }, status=201)
        
    except Exception as e:
        logger.error(f"Error saving grade: {str(e)}")
        return Response({
            'error': f'Failed to save grade: {str(e)}'
        }, status=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_grades_for_quiz(request):
    """
    Get all grades for a specific quiz
    GET /api/grading/grades/?quiz_id=xxx
    """
    try:
        quiz_id = request.query_params.get('quiz_id')
        if not quiz_id:
            return Response({'error': 'quiz_id is required'}, status=400)
        
        teacher_id = str(request.user.id)
        
        # Verify quiz exists and teacher has permission
        try:
            quiz = Quiz.objects.get(id=quiz_id)
        except Quiz.DoesNotExist:
            return Response({'error': 'Quiz not found'}, status=404)
        
        if str(quiz.teacher_id) != teacher_id:
            return Response({'error': 'Permission denied'}, status=403)
        
        # Get all grades for this quiz
        from bson import ObjectId
        try:
            teacher_object_id = ObjectId(teacher_id)
        except Exception as e:
            logger.warning(f"Failed to convert teacher_id to ObjectId: {teacher_id}, error: {str(e)}")
            teacher_object_id = teacher_id
        
        # Query grades with error handling
        try:
            grades = Grade.objects(
                exam_id=quiz_id,
                teacher_id=teacher_object_id
            ).order_by('-scanned_at')
        except Exception as query_error:
            logger.error(f"Error querying grades for quiz {quiz_id}: {str(query_error)}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            # Return empty result instead of 500
            return Response({
                'count': 0,
                'results': []
            })
        
        # Serialize grades one by one to handle individual errors
        results = []
        for grade in grades:
            try:
                serializer = GradeSerializer(grade)
                results.append(serializer.data)
            except Exception as grade_error:
                grade_id = 'unknown'
                try:
                    grade_id = str(getattr(grade, 'id', 'unknown'))
                except:
                    pass
                logger.warning(f"Error serializing grade {grade_id}: {str(grade_error)}")
                import traceback
                logger.warning(f"Traceback: {traceback.format_exc()}")
                # Skip this grade and continue with others
                continue
        
        return Response({
            'count': len(results),
            'results': results
        })
        
    except Exception as e:
        import traceback
        logger.error(f"Error getting grades: {str(e)}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        return Response({'error': str(e)}, status=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def item_analysis(request):
    """
    Get item analysis for a quiz
    GET /api/grading/item-analysis/?quiz_id=xxx
    """
    try:
        quiz_id = request.query_params.get('quiz_id')
        if not quiz_id:
            return Response({'error': 'quiz_id is required'}, status=400)
        
        teacher_id = str(request.user.id)
        
        # Verify quiz exists and teacher has permission
        try:
            quiz = Quiz.objects.get(id=quiz_id)
        except Quiz.DoesNotExist:
            return Response({'error': 'Quiz not found'}, status=404)
        
        if str(quiz.teacher_id) != teacher_id:
            return Response({'error': 'Permission denied'}, status=403)
        
        # Get answer key to know number of questions
        answer_key = AnswerKey.objects(quiz_id=quiz_id).first()
        if not answer_key:
            return Response({
                'error': 'Answer key not found for this quiz'
            }, status=404)
        
        num_questions = answer_key.num_questions
        
        # Get all grades for this quiz
        from bson import ObjectId
        try:
            teacher_object_id = ObjectId(teacher_id)
        except Exception as e:
            logger.warning(f"Failed to convert teacher_id to ObjectId: {teacher_id}, error: {str(e)}")
            teacher_object_id = teacher_id
        
        # Query grades with error handling
        try:
            grades = Grade.objects(
                exam_id=quiz_id,
                teacher_id=teacher_object_id
            )
        except Exception as query_error:
            logger.error(f"Error querying grades for item analysis quiz {quiz_id}: {str(query_error)}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return Response({
                'error': f'Failed to query grades: {str(query_error)}'
            }, status=500)
        
        total_papers = grades.count()
        if total_papers == 0:
            return Response({
                'quiz_id': quiz_id,
                'total_papers': 0,
                'num_questions': num_questions,
                'items': []
            })
        
        # Helper function to get correct answer for a version
        def get_correct_answer_for_version(version_code, question_str):
            """Get correct answer for a specific version and question"""
            if not answer_key.versions:
                return None
            
            # Find version matching version_code
            version = next(
                (v for v in answer_key.versions if v.get('version_code') == version_code),
                None
            )
            
            if not version or 'questions' not in version:
                return None
            
            # Find question in this version
            for q in version['questions']:
                if str(q.get('order', '')) == question_str or str(q.get('question_code', '')) == question_str:
                    return q.get('answer', '')
            
            return None
        
        # Calculate item statistics
        items = []
        for q_idx in range(1, num_questions + 1):
            q_str = str(q_idx)
            
            # Count correct/incorrect for this question
            correct_count = 0
            incorrect_count = 0
            blank_count = 0
            
            # Get correct answer from first version (for display purposes)
            # But we'll check each grade's version when counting
            display_correct_answer = None
            if answer_key.versions and len(answer_key.versions) > 0:
                first_version = answer_key.versions[0]
                if 'questions' in first_version:
                    for q in first_version['questions']:
                        if str(q.get('order', '')) == q_str or str(q.get('question_code', '')) == q_str:
                            display_correct_answer = q.get('answer', '')
                            break
            
            # Count answers - check each grade's version
            for grade in grades:
                answers = grade.answers or {}
                student_answer = answers.get(q_str)
                
                if student_answer is None or student_answer == '' or student_answer == -1:
                    blank_count += 1
                else:
                    # Get correct answer for this grade's version
                    version_code = grade.version_code or ''
                    correct_answer = get_correct_answer_for_version(version_code, q_str)
                    
                    if not correct_answer:
                        # If no correct answer found for this version, count as incorrect
                        incorrect_count += 1
                    else:
                        # Convert both to comparable format
                        # student_answer is stored as index (0, 1, 2, 3, 4) or list [0]
                        # correct_answer is stored as letter ("A", "B", "C", "D", "E")
                        
                        # Handle student_answer - could be int, list, or string
                        student_idx = None
                        if isinstance(student_answer, list):
                            if len(student_answer) > 0:
                                student_idx = student_answer[0]
                        elif isinstance(student_answer, int):
                            student_idx = student_answer
                        elif isinstance(student_answer, str):
                            # Try to parse as int
                            try:
                                student_idx = int(student_answer)
                            except:
                                # If it's a letter, convert to index
                                if len(student_answer) > 0:
                                    student_idx = ord(student_answer.upper()[0]) - ord('A')
                        
                        # Convert correct_answer from letter to index
                        correct_idx = None
                        if isinstance(correct_answer, str) and len(correct_answer) > 0:
                            correct_idx = ord(correct_answer.upper()[0]) - ord('A')
                        elif isinstance(correct_answer, int):
                            correct_idx = correct_answer
                        
                        # Compare
                        if student_idx is not None and correct_idx is not None and student_idx == correct_idx:
                            correct_count += 1
                        else:
                            incorrect_count += 1
            
            # Calculate percentages
            correct_percent = (correct_count / total_papers * 100) if total_papers > 0 else 0
            incorrect_percent = (incorrect_count / total_papers * 100) if total_papers > 0 else 0
            blank_percent = (blank_count / total_papers * 100) if total_papers > 0 else 0
            
            items.append({
                'question_number': q_idx,
                'correct_answer': display_correct_answer or '',
                'correct_count': correct_count,
                'incorrect_count': incorrect_count,
                'blank_count': blank_count,
                'correct_percent': round(correct_percent, 2),
                'incorrect_percent': round(incorrect_percent, 2),
                'blank_percent': round(blank_percent, 2),
            })
        
        # Calculate overall statistics
        scores = [g.score for g in grades if g.score is not None]
        percentages = [g.percentage for g in grades if g.percentage is not None]
        
        min_score = min(scores) if scores else 0
        max_score = max(scores) if scores else 0
        avg_score = sum(scores) / len(scores) if scores else 0
        avg_percent = sum(percentages) / len(percentages) if percentages else 0
        
        # Calculate median
        sorted_scores = sorted(scores) if scores else []
        median_score = sorted_scores[len(sorted_scores) // 2] if sorted_scores else 0
        
        # Calculate standard deviation
        if scores and len(scores) > 1:
            variance = sum((x - avg_score) ** 2 for x in scores) / len(scores)
            std_dev = variance ** 0.5
        else:
            std_dev = 0
        
        return Response({
            'quiz_id': quiz_id,
            'total_papers': total_papers,
            'num_questions': num_questions,
            'items': items,
            'statistics': {
                'min_score': round(min_score, 2),
                'max_score': round(max_score, 2),
                'average_score': round(avg_score, 2),
                'average_percent': round(avg_percent, 2),
                'median_score': round(median_score, 2),
                'std_deviation': round(std_dev, 2),
            }
        })
        
    except Exception as e:
        logger.error(f"Error in item analysis: {str(e)}")
        return Response({'error': str(e)}, status=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_answer_key(request):
    """
    Check if answer key exists for a quiz
    GET /api/grading/check-answer-key/?quiz_id=xxx
    """
    try:
        quiz_id = request.query_params.get('quiz_id')
        if not quiz_id:
            return Response({'error': 'quiz_id is required'}, status=400)
        
        teacher_id = str(request.user.id)
        
        logger.info(f"Checking answer key for quiz_id={quiz_id}, teacher_id={teacher_id}")
        
        # Normalize quiz_id (remove ObjectId wrapper if present)
        normalized_quiz_id = quiz_id
        if quiz_id.startswith('ObjectId('):
            normalized_quiz_id = quiz_id[9:-2]
        
        # Verify quiz exists and teacher has permission
        try:
            quiz = Quiz.objects.get(id=normalized_quiz_id)
            logger.info(f"Found quiz: {quiz.name}, teacher_id={quiz.teacher_id}")
        except Quiz.DoesNotExist:
            logger.warning(f"Quiz not found: {normalized_quiz_id}")
            return Response({'error': 'Quiz not found'}, status=404)
        
        # Check teacher permission
        if str(quiz.teacher_id) != teacher_id:
            logger.warning(f"Permission denied: quiz.teacher_id={quiz.teacher_id}, request.teacher_id={teacher_id}")
            return Response({'error': 'Permission denied'}, status=403)
        
        # Get quiz.id as string (this is the actual ObjectId string)
        quiz_id_str = str(quiz.id)
        logger.info(f"Quiz ID as string: {quiz_id_str}, normalized_quiz_id: {normalized_quiz_id}")
        
        # Check if answer key exists - try multiple formats
        answer_key = None
        
        # Try 1: Query with quiz.id as string (most likely format)
        answer_key = AnswerKey.objects(quiz_id=quiz_id_str).first()
        if answer_key:
            logger.info(f"Found answer key with quiz_id_str={quiz_id_str}")
        else:
            # Try 2: Query with normalized quiz_id
            answer_key = AnswerKey.objects(quiz_id=normalized_quiz_id).first()
            if answer_key:
                logger.info(f"Found answer key with normalized_quiz_id={normalized_quiz_id}")
            else:
                # Try 3: Query with original quiz_id
                answer_key = AnswerKey.objects(quiz_id=quiz_id).first()
                if answer_key:
                    logger.info(f"Found answer key with original quiz_id={quiz_id}")
        
        # Also filter by teacher_id to ensure correct answer key
        if answer_key:
            # Verify answer key belongs to this teacher
            if str(answer_key.id_teacher) != teacher_id:
                logger.warning(f"Answer key found but belongs to different teacher: {answer_key.id_teacher} != {teacher_id}")
                answer_key = None
            else:
                logger.info(f"Answer key verified: quiz_id={answer_key.quiz_id}, id_teacher={answer_key.id_teacher}")
        
        # Debug: List all answer keys for this teacher to see what's stored
        all_keys = AnswerKey.objects(id_teacher=teacher_id)
        logger.info(f"All answer keys for teacher {teacher_id}: {[(str(ak.quiz_id), ak.quiz_id == quiz_id_str) for ak in all_keys[:5]]}")
        
        has_key = answer_key is not None
        logger.info(f"Answer key check result: has_answer_key={has_key} for quiz_id={normalized_quiz_id}")
        
        return Response({
            'has_answer_key': has_key,
            'quiz_id': normalized_quiz_id
        })
        
    except Exception as e:
        logger.error(f"Error checking answer key: {str(e)}", exc_info=True)
        return Response({'error': str(e)}, status=500)
