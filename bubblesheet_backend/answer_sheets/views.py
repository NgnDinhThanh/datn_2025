# Create your views here.
import contextlib

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from django.http import FileResponse, JsonResponse, HttpResponse
import logging
import traceback
import os
from datetime import datetime
import shutil
from answer_sheets.models import AnswerSheetTemplate
from answer_sheets.serializers import AnswerSheetTemplateSerializer
from answer_sheets.utils import (
    generate_answer_sheet,
    cleanup_old_backups,
    validate_file_size,
    validate_file_type,
    handle_file_operation_error,
    get_file_info
)
from django.conf import settings
from django.core.files.storage import default_storage
from rest_framework import viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.views.decorators.csrf import csrf_exempt

# Set up logging
logger = logging.getLogger(__name__)


@contextlib.contextmanager
def safe_file_operation(file_path, mode='rb'):
    """Context manager để xử lý file an toàn"""
    try:
        with open(file_path, mode) as f:
            yield f
    except Exception as e:
        logger.error(f"Error handling file {file_path}: {str(e)}")
        raise


def safe_remove_file(file_path):
    """Xóa file an toàn"""
    try:
        if file_path and os.path.exists(file_path):
            os.remove(file_path)
            logger.info(f"Successfully removed file: {file_path}")
    except Exception as e:
        logger.error(f"Error removing file {file_path}: {str(e)}")


class AnswerSheetTemplateViewSet(viewsets.ModelViewSet):
    serializer_class = AnswerSheetTemplateSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return AnswerSheetTemplate.objects.filter(teacher_id=self.request.user.id)

    def create(self, request, *args, **kwargs):
        try:
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            template = serializer.save()
            template.reload()

            file_id = str(template.pk)
            pdf_path = None
            json_path = None

            try:
                pdf_path, json_path = generate_answer_sheet(
                    template=template,
                    output_dir=settings.ANSWER_SHEET_CONFIG['OUTPUT_DIR'],
                    aruco_dir=settings.ANSWER_SHEET_CONFIG['ARUCO_MARKER_DIR'],
                    file_id=file_id
                )

                template.file_pdf = pdf_path
                template.file_json = json_path
                template.save()

                return Response(self.get_serializer(template).data, status=status.HTTP_201_CREATED)
            except Exception as e:
                # Cleanup nếu có lỗi
                safe_remove_file(pdf_path)
                safe_remove_file(json_path)
                raise e

        except Exception as e:
            logger.error(f"Error creating template: {str(e)}\n{traceback.format_exc()}")
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['get'])
    def preview(self, request, pk=None):
        try:
            template = self.get_object()
            preview_path = os.path.join(
                settings.ANSWER_SHEET_CONFIG['PREVIEW_DIR'],
                f'{template.id}_preview.png'
            )
            if not os.path.exists(preview_path):
                logger.warning(f"Preview not found for template: {template.id}")
                return Response(
                    {'error': 'Preview not found. Please generate the answer sheet first.'},
                    status=status.HTTP_404_NOT_FOUND
                )
            logger.info(f"Serving preview for template: {template.id}")
            f = open(preview_path, 'rb')
            return FileResponse(f, content_type='image/png')
        except Exception as e:
            logger.error(f"Error getting preview: {str(e)}")
            logger.error(f"Traceback: {traceback.format_exc()}")
            return Response(
                {'error': 'Failed to get preview'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=['get'], url_path='download/pdf')
    def download_pdf(self, request, pk=None):
        try:
            template = self.get_object()
            logger.info(f"[DOWNLOAD PDF] Template id: {template.id}, file_pdf: {template.file_pdf}")
            if not template.file_pdf or not os.path.exists(template.file_pdf):
                logger.error(f"[DOWNLOAD PDF] PDF file not found for template {template.id}: {template.file_pdf}")
                return Response({'error': 'PDF file not found'}, status=status.HTTP_404_NOT_FOUND)
            f = open(template.file_pdf, 'rb')
            return FileResponse(
                f,
                as_attachment=True,
                filename=os.path.basename(template.file_pdf),
                content_type='application/pdf'
            )
        except Exception as e:
            logger.error(f"[DOWNLOAD PDF] Error downloading PDF for template {pk}: {str(e)}")
            return Response({'error': 'Failed to download PDF'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=True, methods=['get'], url_path='download/png')
    def download_png(self, request, pk=None):
        try:
            template = self.get_object()
            preview_path = os.path.join(
                settings.ANSWER_SHEET_CONFIG['PREVIEW_DIR'],
                f'{template.id}_preview.png'
            )
            logger.info(f"[DOWNLOAD PNG] Template id: {template.id}, preview_path: {preview_path}")
            if not os.path.exists(preview_path):
                logger.error(f"[DOWNLOAD PNG] PNG file not found for template {template.id}: {preview_path}")
                return Response({'error': 'PNG file not found'}, status=status.HTTP_404_NOT_FOUND)
            f = open(preview_path, 'rb')
            return FileResponse(
                f,
                as_attachment=True,
                filename=f'{template.name}_preview.png',
                content_type='image/png'
            )
        except Exception as e:
            logger.error(f"[DOWNLOAD PNG] Error downloading PNG for template {pk}: {str(e)}")
            return Response({'error': 'Failed to download PNG'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['post'], url_path='generate_preview')
    def generate_preview(self, request):
        """
        Nhận dữ liệu answer sheet, generate preview và trả về ảnh PNG (bytes).
        """
        try:
            data = request.data
            template = AnswerSheetTemplate(
                name=data.get('name', 'Preview'),
                labels=data.get('labels', ['Name', 'Quiz', 'Class', 'Score']),
                num_questions=int(data.get('num_questions', 50)),
                num_options=int(data.get('num_options', 5)),
                student_id_digits=int(data.get('student_id_digits', 5)),
                exam_id_digits=int(data.get('exam_id_digits', 5)),
                class_id_digits=int(data.get('class_id_digits', 5)),
                teacher_id=request.user.id,
                created_at=datetime.now().isoformat(),
                updated_at=datetime.now().isoformat()
            )
            from answer_sheets.utils import generate_answer_sheet
            pdf_path, _ = generate_answer_sheet(template)
            import fitz
            preview_path = pdf_path.replace('.pdf', '_preview.png')
            doc = fitz.open(pdf_path)
            page = doc[0]
            pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
            pix.save(preview_path)
            doc.close()
            f = open(preview_path, 'rb')
            response = FileResponse(f, content_type='image/png')
            return response
        except Exception as e:
            import traceback
            logger.error(f"Error generating preview: {str(e)}\n{traceback.format_exc()}")
            return Response({'error': f'Failed to generate preview: {str(e)}'}, status=500)


class AnswerSheetTemplateListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            templates = AnswerSheetTemplate.objects(teacher_id=request.user.id)
            logger.info(f"Retrieved {len(templates)} answer sheets for teacher {request.user.id}")
            serializer = AnswerSheetTemplateSerializer(templates, many=True)
            return Response(serializer.data)
        except Exception as e:
            logger.error(f"Error getting answer sheets: {str(e)}\n{traceback.format_exc()}")
            return Response(
                {'error': 'Failed to retrieve answer sheets'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def post(self, request):
        try:
            serializer = AnswerSheetTemplateSerializer(data=request.data)
            if not serializer.is_valid():
                logger.warning(f"Invalid answer sheet data: {serializer.errors}")
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

            name = request.data.get('name')
            if AnswerSheetTemplate.objects(name=name, teacher_id=request.user.id).first():
                logger.warning(f"Answer sheet template with name {name} already exists")
                return Response(
                    {"error": "Template with this name already exists"},
                    status=status.HTTP_400_BAD_REQUEST
                )

            template = AnswerSheetTemplate(
                name=name,
                labels=request.data.get('labels', ['Name', 'Quiz', 'Class', 'Score']),
                num_questions=int(request.data.get('num_questions', 50)),
                num_options=int(request.data.get('num_options', 5)),
                student_id_digits=int(request.data.get('student_id_digits', 5)),
                exam_id_digits=int(request.data.get('exam_id_digits', 5)),
                class_id_digits=int(request.data.get('class_id_digits', 5)),
                teacher_id=request.user.id,
                created_at=datetime.now().isoformat(),
                updated_at=datetime.now().isoformat()
            )

            template.save()
            template.reload()

            file_id = str(
                getattr(template, 'pk', None) or getattr(template, 'id', None) or getattr(template, '_id', None))
            logger.info(f"file_id to use for file naming: {file_id}")

            pdf_path = None
            json_path = None

            try:
                pdf_path, json_path = generate_answer_sheet(
                    template=template,
                    output_dir=settings.ANSWER_SHEET_CONFIG['OUTPUT_DIR'],
                    aruco_dir=settings.ANSWER_SHEET_CONFIG['ARUCO_MARKER_DIR'],
                    file_id=file_id
                )

                validate_file_size(pdf_path, max_size_mb=10)
                validate_file_type(pdf_path, ['.pdf'])
                validate_file_type(json_path, ['.json'])

                cleanup_old_backups(settings.ANSWER_SHEET_CONFIG['OUTPUT_DIR'])

                template.file_pdf = pdf_path
                template.file_json = json_path
                template.save()

                return Response(AnswerSheetTemplateSerializer(template).data, status=status.HTTP_201_CREATED)

            except Exception as e:
                # Cleanup nếu có lỗi
                safe_remove_file(pdf_path)
                safe_remove_file(json_path)
                template.delete()
                return handle_file_operation_error(e, [pdf_path, json_path])

        except Exception as e:
            logger.error(f"Error creating answer sheet: {str(e)}\n{traceback.format_exc()}")
            return Response(
                {'error': 'Failed to create answer sheet'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AnswerSheetTemplateDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, id):
        try:
            template = AnswerSheetTemplate.objects.get(id=id)
            logger.debug(f"Found answer sheet template {id}")
            return template
        except AnswerSheetTemplate.DoesNotExist:
            logger.warning(f"Answer sheet template {id} not found")
            return None
        except Exception as e:
            logger.error(f"Error retrieving answer sheet template {id}: {str(e)}")
            return None

    def get(self, request, id):
        try:
            template_obj = self.get_object(id)
            if not template_obj:
                return Response(
                    {'error': 'Answer sheet template not found'},
                    status=status.HTTP_404_NOT_FOUND
                )

            if template_obj.teacher_id != request.user.id:
                logger.warning(f"User {request.user.id} attempted to access answer sheet {id} without permission")
                return Response(
                    {"error": "You don't have permission to view this answer sheet"},
                    status=status.HTTP_403_FORBIDDEN
                )

            serializer = AnswerSheetTemplateSerializer(template_obj)
            return Response(serializer.data)

        except Exception as e:
            logger.error(f"Error retrieving answer sheet details: {str(e)}")
            return Response(
                {'error': "Failed to retrieve answer sheet details"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def put(self, request, id):
        try:
            template_obj = self.get_object(id)
            if not template_obj:
                return Response(
                    {'error': 'Answer sheet template not found'},
                    status=status.HTTP_404_NOT_FOUND
                )

            if template_obj.teacher_id != request.user.id:
                logger.warning(f"User {request.user.id} attempted to update answer sheet {id} without permission")
                return Response(
                    {"error": "You don't have permission to update this answer sheet"},
                    status=status.HTTP_403_FORBIDDEN
                )

            serializer = AnswerSheetTemplateSerializer(template_obj, data=request.data)
            if serializer.is_valid():
                for attr, value in serializer.validated_data.items():
                    setattr(template_obj, attr, value)
                template_obj.save()
                logger.info(f"Updated answer sheet template {id}")
                return Response(AnswerSheetTemplateSerializer(template_obj).data)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            logger.error(f"Error updating answer sheet: {str(e)}")
            return Response(
                {'error': "Failed to update answer sheet"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def delete(self, request, id):
        try:
            template_obj = self.get_object(id)
            if not template_obj:
                return Response(
                    {'error': 'Answer sheet template not found'},
                    status=status.HTTP_404_NOT_FOUND
                )

            if template_obj.teacher_id != request.user.id:
                logger.warning(f"User {request.user.id} attempted to delete answer sheet {id} without permission")
                return Response(
                    {"error": "You don't have permission to delete this answer sheet"},
                    status=status.HTTP_403_FORBIDDEN
                )

            # Delete associated files
            safe_remove_file(template_obj.file_pdf)
            safe_remove_file(template_obj.file_json)
            safe_remove_file(template_obj.file_png)
            safe_remove_file(template_obj.preview_image)

            if template_obj.backup_dir and os.path.exists(template_obj.backup_dir):
                try:
                    shutil.rmtree(template_obj.backup_dir)
                except Exception as e:
                    logger.error(f"Error removing backup directory: {str(e)}")

            template_obj.delete()
            logger.info(f"Deleted answer sheet template {id}")
            return Response(status=status.HTTP_204_NO_CONTENT)

        except Exception as e:
            logger.error(f"Error deleting answer sheet: {str(e)}")
            return Response(
                {'error': "Failed to delete answer sheet"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AnswerSheetPreviewView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, id):
        try:
            template = AnswerSheetTemplate.objects.get(id=id)

            # Check permissions
            if template.teacher_id != request.user.id:
                logger.warning(f"User {request.user.id} attempted to access preview without permission")
                return Response(
                    {"error": "You don't have permission to view this preview"},
                    status=status.HTTP_403_FORBIDDEN
                )

            # Check if preview exists
            if not template.preview_image or not os.path.exists(template.preview_image):
                logger.warning(f"Preview not found for template {id}")
                return Response(
                    {"error": "No preview available"},
                    status=status.HTTP_404_NOT_FOUND
                )

            # Validate file
            try:
                validate_file_size(template.preview_image, max_size_mb=5)
                validate_file_type(template.preview_image, ['.png'])
            except Exception as e:
                logger.error(f"Error validating preview file: {str(e)}")
                return Response(
                    {"error": "Invalid preview file"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )

            # Return file
            return FileResponse(
                open(template.preview_image, 'rb'),
                content_type='image/png'
            )

        except AnswerSheetTemplate.DoesNotExist:
            logger.warning(f"Template {id} not found")
            return Response(
                {"error": "Template not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.error(f"Error retrieving preview: {str(e)}")
            return Response(
                {"error": "Failed to retrieve preview"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )