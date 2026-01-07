from rest_framework import serializers
from users.models import User
from bson import ObjectId
from classes.models import Class

class ObjectIdField(serializers.Field):
    def to_representation(self, value):
        return str(value)

    def to_internal_value(self, data):
        return ObjectId(data)

class ClassSerializer(serializers.Serializer):
    class_code = serializers.CharField(min_length=3, max_length=10)
    class_name = serializers.CharField(min_length=2, max_length=100)
    student_count = serializers.IntegerField(read_only=True)
    teacher_id = ObjectIdField(read_only=True)
    student_ids = serializers.ListField(child=ObjectIdField(), read_only=True)
    exam_ids = serializers.ListField(child=ObjectIdField(), read_only=True)

    def validate_class_code(self, value):
        if not value.isalnum():
            raise serializers.ValidationError("Class code must contain only letters and numbers")
        return value

    def to_representation(self, instance):
        # Convert MongoDB document to dict with ID
        data = {
            'id': str(instance.id),
            'class_code': instance.class_code,
            'class_name': instance.class_name,
            'student_count': instance.student_count,
            'teacher_id': str(instance.teacher_id),  # Convert ObjectId to string
            'student_ids': [str(id) for id in instance.student_ids],
            'exam_ids': [str(id) for id in instance.exam_ids]
        }
        return data