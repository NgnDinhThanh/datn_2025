# Create your views here.
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
import logging

from exams.models import Exam
from exams.serializers import ExamSerializer
from answer_keys.models import AnswerKey

logger = logging.getLogger(__name__)

class ExamListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ExamSerializer

    def get_queryset(self):
        return Exam.objects(teacher_id=self.request.user.id)

    def perform_create(self, serializer):
        serializer.save(teacher_id=self.request.user.id)

    def create(self, request, *args, **kwargs):
        try:
            return super().create(request, *args, **kwargs)
        except Exception as e:
            logger.error(f"Error in create exam: {str(e)}")
            return Response({
                "error": "Failed to create exam",
                "detail": str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class ExamDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ExamSerializer

    def get_queryset(self):
        return Exam.objects(teacher_id=self.request.user.id)

    def get_object(self, pk):
        return Exam.objects(id=pk).first()

    def get(self, request, pk):
        exam_obj = self.get_object(pk)
        if not exam_obj:
            return Response({'error': 'Not found'}, status=404)
        serializer = ExamSerializer(exam_obj, context={'request': request})
        return Response(serializer.data)

    def update(self, request, *args, **kwargs):
        try:
            partial = kwargs.pop('partial', False)
            instance = self.get_object(kwargs.get('pk'))
            if not instance:
                return Response({'error': 'Not found'}, status=404)
            old_answersheet = instance.answersheet
            serializer = self.get_serializer(instance, data=request.data, partial=partial, context={'request': request})
            serializer.is_valid(raise_exception=True)
            self.perform_update(serializer)
            # Sau khi update, kiểm tra nếu answersheet thay đổi thì xóa answer key cũ
            new_answersheet = serializer.validated_data.get('answersheet', old_answersheet)
            if old_answersheet != new_answersheet:
                AnswerKey.objects.filter(quiz_id=str(instance.id)).delete()
                logger.info(f"Deleted all answer keys for quiz {instance.id} after changing answer sheet.")
            return Response(serializer.data)
        except Exception as e:
            logger.error(f"Error in update exam: {str(e)}")
            return Response({
                "error": "Failed to update exam",
                "detail": str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def perform_update(self, serializer):
        serializer.save()

    def delete(self, request, pk, *args, **kwargs):
        try:
            instance = self.get_object(pk)
            if not instance:
                return Response({'error': 'Not found'}, status=404)
            
            self.perform_delete(instance)
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Exception as e:
            logger.error(f"Error in delete exam: {str(e)}")
            return Response({
                "error": "Failed to delete exam",
                "detail": str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def perform_delete(self, instance):
        instance.delete()