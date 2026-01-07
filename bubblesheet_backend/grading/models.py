from mongoengine import Document, StringField, FloatField, DictField, DateTimeField, ObjectIdField
from datetime import datetime


# Create your models here.
class Grade(Document):
    # Existing fields
    class_code = StringField(required=True)
    exam_id = StringField(required=True)  # quiz_id
    student_id = StringField(required=True)
    score = FloatField()
    answers = DictField()  # {question_index: answer_index}
    
    # New fields
    percentage = FloatField(default=0.0)  # Percentage score
    scanned_image = StringField()  # Path to scanned image (for debugging)
    annotated_image = StringField()  # Path to annotated image (for display)
    scanned_at = DateTimeField(default=datetime.now)
    version_code = StringField()  # Version code of answer key
    answersheet_id = StringField()  # Link to AnswerSheetTemplate
    teacher_id = ObjectIdField()  # Teacher ID (optional for backward compatibility)
    created_at = DateTimeField(default=datetime.now)
    updated_at = DateTimeField(default=datetime.now)
    
    meta = {
        'collection': 'grades',
        'strict': False,  # Ignore fields not defined in model (e.g., is_latest, attempt_number from old data)
        'indexes': [
            'exam_id',
            'student_id',
            'class_code',
            'teacher_id',
            'version_code',
            'scanned_at',
        ],
        'ordering': ['-scanned_at']
    }
    
    def save(self, *args, **kwargs):
        """Override save to update updated_at"""
        self.updated_at = datetime.now()
        return super().save(*args, **kwargs)