from bson import ObjectId
from rest_framework import serializers

class ObjectIdField(serializers.Field):
    def to_representation(self, value):
        return str(value)

    def to_internal_value(self, data):
        return ObjectId(data)


class StudentSerializer(serializers.Serializer):
    student_id = serializers.CharField(max_length=8)
    first_name = serializers.CharField(max_length=200)
    last_name = serializers.CharField(max_length=200)
    teacher_id = ObjectIdField(read_only=True)
    class_codes = serializers.ListField(child=ObjectIdField(), required=False)

    def validate_student_id(self, value):
        if not value.isalnum():
            raise serializers.ValidationError("Student ID must contain only letters and numbers")
        return value

    def to_representation(self, instance):
        data = {
            '_id': str(instance.id),
            'student_id': instance.student_id,
            'first_name': instance.first_name,
            'last_name': instance.last_name,
            'teacher_id': str(instance.teacher_id),
            'class_codes': [str(id) for id in instance.class_codes]
        }
        return data
