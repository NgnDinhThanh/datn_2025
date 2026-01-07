from mongoengine import Document, StringField, ListField, DictField, IntField, ValidationError, ObjectIdField
from users.models import User
import re
from datetime import datetime
import os


# Create your models here.
class AnswerSheetTemplate(Document):
    name = StringField(required=True, max_length=100)
    labels = ListField(StringField(), required=True)
    num_questions = IntField(required=True, min_value=1, max_value=100)
    num_options = IntField(required=True, min_value=2, max_value=5)
    student_id_digits = IntField(required=True, min_value=3, max_value=8)
    exam_id_digits = IntField(required=True, min_value=2, max_value=6)
    class_id_digits = IntField(required=True, min_value=2, max_value=6)
    preview_image = StringField()
    teacher_id = ObjectIdField(required=True)
    file_pdf = StringField()
    file_json = StringField()
    file_png = StringField()
    created_at = StringField(required=True)
    updated_at = StringField(required=True)
    backup_dir = StringField()

    meta = {
        'collection': 'answer_sheet_templates',
        'indexes': ['name', 'teacher_id'],
        'ordering': ['-created_at']
    }

    def clean(self):
        # Validate name format
        if not re.match(r'^[A-Za-z0-9\s\-_]+$', self.name):
            raise ValidationError('Name must contain only alphanumeric characters, spaces, hyphens and underscores')

        # Validate labels
        if not self.labels:
            raise ValidationError('Labels are required')
        for label in self.labels:
            if not isinstance(label, str):
                raise ValidationError('Each label must be a string')

        # Validate teacher exists
        teacher = User.objects(id=self.teacher_id, is_teacher=True).first()
        if not teacher:
            raise ValidationError("Teacher not found or is not a teacher")

        # Validate file paths
        if self.file_pdf and not self.file_pdf.endswith('.pdf'):
            raise ValidationError('Valid PDF file path is required')
        if self.file_json and not self.file_json.endswith('.json'):
            raise ValidationError('Valid JSON file path is required')
        if self.file_png and not self.file_png.endswith('.png'):
            raise ValidationError('PNG file path must end with .png')
        if self.preview_image and not self.preview_image.endswith('.png'):
            raise ValidationError('Preview image must end with .png')

        # Set timestamps if not set
        if not self.created_at:
            self.created_at = datetime.now().isoformat()
        if not self.updated_at:
            self.updated_at = datetime.now().isoformat()

    def save(self, *args, **kwargs):
        """Override save to update updated_at"""
        self.updated_at = datetime.now().isoformat()
        return super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        try:
            # Delete associated files
            if self.file_pdf and os.path.exists(self.file_pdf):
                os.remove(self.file_pdf)
            if self.file_json and os.path.exists(self.file_json):
                os.remove(self.file_json)
            if self.file_png and os.path.exists(self.file_png):
                os.remove(self.file_png)
            # Xóa preview_image nếu có
            if self.preview_image and os.path.exists(self.preview_image):
                os.remove(self.preview_image)
            # Luôn xóa file preview theo id nếu tồn tại
            try:
                from django.conf import settings
                preview_path = os.path.join(
                    settings.ANSWER_SHEET_CONFIG['PREVIEW_DIR'],
                    f'{self.id}_preview.png'
                )
                if os.path.exists(preview_path):
                    os.remove(preview_path)
            except Exception as e:
                print(f"Error cleaning up preview file by id: {str(e)}")
            if self.backup_dir and os.path.exists(self.backup_dir):
                import shutil
                shutil.rmtree(self.backup_dir)
        except Exception as e:
            print(f"Error cleaning up files: {str(e)}")
        super().delete(*args, **kwargs)
