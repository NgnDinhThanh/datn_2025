from mongoengine import Document, StringField, IntField, ListField, ValidationError, ObjectIdField

from users.models import User
import re
from bson import ObjectId


# Create your models here.
class Class(Document):
    class_code = StringField(required=True, unique=True, max_length=20)
    class_name = StringField(required=True, max_length=100)
    student_count = IntField(default=0)
    teacher_id = ObjectIdField(required=True)
    student_ids = ListField(ObjectIdField())
    exam_ids = ListField(ObjectIdField())

    meta = {
        'collection': 'classes',
        'indexes': ['class_code', 'teacher_id']
    }

    def clean(self):
        from students.models import Student  # Import động để tránh circular import
        from exams.models import Exam  # Import động để tránh circular import
        # Validate class_code format
        if not re.match(r'^[A-Za-z0-9]+$', self.class_code):
            raise ValidationError('Class code must contain only alphanumeric characters')

        # Validate student_ids
        if self.student_ids:
            for student_id in self.student_ids:
                if not isinstance(student_id, ObjectId):
                    raise ValidationError('Student ID must be a valid ObjectId')
        
        # Validate teacher exists
        teacher = User.objects(id=self.teacher_id, is_teacher=True).first()
        if not teacher:
            raise ValidationError("Teacher not found or is not a teacher")
        
        # Validate student_ids if provided
        if self.student_ids:
            for student_id in self.student_ids:
                student = Student.objects(id=student_id).first()
                if not student:
                    raise ValidationError(f"Student with id {student_id} not found")
        
        # Validate exam_ids if provided
        if self.exam_ids:
            for exam_id in self.exam_ids:
                exam = Exam.objects(id=exam_id).first()
                if not exam:
                    raise ValidationError(f"Exam with id {exam_id} not found")
        
        # Update student_count
        self.student_count = len(self.student_ids)

    def delete(self, *args, **kwargs):
        from exams.models import Exam
        class_code_to_remove = self.class_code

        # 1. Tìm tất cả các exam có chứa class_code này
        exams = Exam.objects(class_codes=class_code_to_remove)

        # 2. Xóa class_code khỏi các exam
        for exam in exams:
            if class_code_to_remove in exam.class_codes:
                exam.class_codes.remove(class_code_to_remove)
                exam.save()

        # 3. Xóa exam_ids khỏi class (không bắt buộc, vì sắp xóa class)
        self.exam_ids = []
        self.save()

        # 4. Xóa class
        super().delete(*args, **kwargs)