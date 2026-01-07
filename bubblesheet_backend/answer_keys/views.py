import io
from datetime import datetime

from django.shortcuts import render
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from .models import AnswerKey
from .serializers import (
    AnswerKeySerializer,
    GenerateAnswerKeySerializer,
    AnswerKeyDetailSerializer
)
import csv
import random
from django.core.exceptions import ValidationError
from exams.models import Exam as Quiz
from answer_sheets.models import AnswerSheetTemplate
from django.http import HttpResponse
import openpyxl

# Create your views here.

class GenerateAnswerKeyView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # Validate input
        serializer = GenerateAnswerKeySerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        quiz_id = serializer.validated_data['quiz_id']
        num_versions = serializer.validated_data['num_versions']
        answer_file = serializer.validated_data['answer_file']

        try:
            # Get quiz and answer sheet info
            quiz = Quiz.objects.get(id=quiz_id)
            answer_sheet = AnswerSheetTemplate.objects.get(id=quiz.answersheet)

            # Process answer bank file
            answer_bank = self._process_answer_bank(answer_file)

            # Validate number of questions
            if len(answer_bank) < answer_sheet.num_questions:
                return Response(
                    {'error': 'Answer bank must contain at least num_questions questions'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Generate versions
            versions = self._generate_versions(
                answer_bank,
                answer_sheet.num_questions,
                num_versions,
                answer_sheet.exam_id_digits
            )

            # Normalize quiz_id to ensure consistent format (use str(quiz.id))
            # This ensures we always use the ObjectId string format
            normalized_quiz_id = str(quiz.id)
            
            # Check if AnswerKey for this quiz already exists
            # Try querying with both formats to handle existing data
            answer_key = AnswerKey.objects(quiz_id=normalized_quiz_id).first()
            if not answer_key:
                # Try with original quiz_id format (for backward compatibility)
                answer_key = AnswerKey.objects(quiz_id=quiz_id).first()
            
            if answer_key:
                # Update existing
                answer_key.id_teacher = str(request.user.id)
                answer_key.quiz_id = normalized_quiz_id  # Update to normalized format
                answer_key.answersheet_id = quiz.answersheet
                answer_key.num_questions = answer_sheet.num_questions
                answer_key.num_exam_id = answer_sheet.exam_id_digits
                answer_key.num_versions = num_versions
                answer_key.answer_bank = answer_bank
                answer_key.versions = versions
                answer_key.updated_at = datetime.now()
                answer_key.save()
                status_code = status.HTTP_200_OK
            else:
                # Create new - always use normalized quiz_id (str(quiz.id))
                answer_key = AnswerKey(
                    id_teacher=str(request.user.id),
                    quiz_id=normalized_quiz_id,  # Use normalized format
                    answersheet_id=quiz.answersheet,
                    num_questions=answer_sheet.num_questions,
                    num_exam_id=answer_sheet.exam_id_digits,
                    num_versions=num_versions,
                    answer_bank=answer_bank,
                    versions=versions
                )
                answer_key.save()
                status_code = status.HTTP_201_CREATED

            return Response(
                AnswerKeySerializer(answer_key).data,
                status=status_code
            )

        except Quiz.DoesNotExist:
            return Response(
                {'error': 'Quiz not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        except AnswerSheetTemplate.DoesNotExist:
            return Response(
                {'error': 'Answer sheet not found'},
                status=status.HTTP_404_NOT_FOUND
            )
        except ValidationError as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )

    def _process_answer_bank(self, file):
        text_stream = io.StringIO(file.read().decode('utf-8'))
        questions = []
        reader = csv.reader(text_stream)
        
        # Check if first row is header
        first_row = next(reader, None)
        if first_row and len(first_row) > 1:
            # 2+ columns format with header
            start_index = 1
            for index, row in enumerate(reader, start=2):
                if not row or len(row) < 2:
                    continue
                answer = row[1].strip().upper()  # Lấy cột thứ 2 (đáp án)
                # Remove BOM character if present
                answer = answer.replace('\ufeff', '')
                if answer not in ['A', 'B', 'C', 'D', 'E']:
                    raise ValidationError(f"Invalid answer at line {index}: {answer}")
                
                questions.append({
                    'question_code': row[0].strip(),  # Lấy cột đầu (số câu hỏi)
                    'answer': answer
                })
        else:
            # 1 column format (original)
            if first_row:
                answer = first_row[0].strip().upper()
                answer = answer.replace('\ufeff', '')
                if answer in ['A', 'B', 'C', 'D', 'E']:
                    questions.append({
                        'question_code': '1',
                        'answer': answer
                    })
            
            for index, row in enumerate(reader, start=2):
                if not row or not row[0].strip():
                    continue
                answer = row[0].strip().upper()
                answer = answer.replace('\ufeff', '')
                if answer not in ['A', 'B', 'C', 'D', 'E']:
                    raise ValidationError(f"Invalid answer at line {index}: {answer}")
                
                questions.append({
                    'question_code': str(index),
                    'answer': answer
                })
        
        return questions

    def _generate_versions(self, answer_bank, num_questions, num_versions, num_exam_id):
        versions = []
        for i in range(num_versions):
            # Select random questions
            selected_questions = random.sample(answer_bank, num_questions)
            
            # Create version
            version = {
                'version_code': str(i + 1).zfill(num_exam_id),
                'questions': [
                    {
                        'question_code': q['question_code'],
                        'answer': q['answer'],
                        'order': j + 1
                    }
                    for j, q in enumerate(selected_questions)
                ]
            }
            versions.append(version)
        return versions

class AnswerKeyListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, quiz_id):
        print(f"[DEBUG] Backend received quiz_id: {quiz_id}")
        print(f"[DEBUG] Current user id: {str(request.user.id)}")
        for a in AnswerKey.objects.all():
            print(f"[DEBUG] AnswerKey quiz_id: {a.quiz_id}, id_teacher: {a.id_teacher}")
        answer_keys = AnswerKey.objects.filter(
            quiz_id=quiz_id,
            id_teacher=str(request.user.id)
        )
        print(f"[DEBUG] Found answer keys: {[a.quiz_id for a in answer_keys]}")
        print(f"[DEBUG] All answer keys for teacher: {[a.quiz_id for a in AnswerKey.objects.filter(id_teacher=str(request.user.id))]}")
        return Response(
            AnswerKeyDetailSerializer(answer_keys, many=True).data
        )

class AnswerKeyDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, answer_key_id):
        try:
            answer_key = AnswerKey.objects.get(
                id=answer_key_id,
                id_teacher=request.user.id
            )
            return Response(AnswerKeySerializer(answer_key).data)
        except AnswerKey.DoesNotExist:
            return Response(
                {'error': 'Answer key not found'},
                status=status.HTTP_404_NOT_FOUND
            )

class AnswerKeyDownloadAllExcelView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, quiz_id):
        answer_keys = AnswerKey.objects.filter(quiz_id=quiz_id, id_teacher=str(request.user.id))
        if not answer_keys:
            return HttpResponse('No answer keys found.', status=404)
        answer_key = answer_keys.first()
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.append(['Version Code', 'Order', 'Question Code', 'Answer'])
        for version in answer_key.versions:
            version_code = version.get('version_code', '')
            for q in version.get('questions', []):
                ws.append([
                    version_code,
                    q.get('order', ''),
                    q.get('question_code', ''),
                    q.get('answer', ''),
                ])
        import io
        output = io.BytesIO()
        wb.save(output)
        output.seek(0)
        response = HttpResponse(output, content_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        response['Content-Disposition'] = f'attachment; filename=answer_keys_{quiz_id}.xlsx'
        return response
