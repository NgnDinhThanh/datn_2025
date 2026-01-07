import re

from bson import ObjectId
from mongoengine import Document, StringField, ObjectIdField, ListField, ValidationError

from classes.models import Class
from users.models import User


# Create your models here.
class Student(Document):
    student_id = StringField(required=True, unique=True, max_length=8)
    first_name = StringField(required=True, max_length=200)
    last_name = StringField(required=True, max_length=200)
    teacher_id = ObjectIdField(required=True)
    class_codes = ListField(ObjectIdField())

    meta = {
        'collection': 'students',
        'indexes': ['student_id', 'teacher_id']
    }

    def clean(self):
        if not re.match(r'^[A-Za-z0-9]+$', self.student_id):
            raise ValidationError('Student ID must contain only alphanumeric characters')

        if self.class_codes:
            for class_code in self.class_codes:
                if not isinstance(class_code, ObjectId):
                    raise ValidationError('Class code must be a valid ObjectId')

        teacher = User.objects(id=self.teacher_id, is_teacher=True).first()
        if not teacher:
            raise ValidationError("Teacher not found or is not a teacher")

        if self.class_codes:
            for class_code in self.class_codes:
                class_ = Class.objects(id=class_code, teacher_id=self.teacher_id).first()
                if not class_:
                    raise ValidationError(f"Class with code {class_code} not found or is not owned by teacher")
