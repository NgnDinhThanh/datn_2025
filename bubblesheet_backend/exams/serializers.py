from rest_framework import serializers
from .models import Exam
from users.models import User
from classes.models import Class
from answer_sheets.models import AnswerSheetTemplate
import re


class ExamSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    name = serializers.CharField(max_length=100)
    class_codes = serializers.ListField(
        child=serializers.CharField(),
        required=False
    )
    answersheet = serializers.CharField(required=True)
    date = serializers.CharField(required=True)
    teacher_id = serializers.CharField(read_only=True)

    def validate_date(self, value):
        # Kiểm tra định dạng ngày tháng năm (yyyy-mm-dd)
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', value):
            raise serializers.ValidationError("Date must be in format yyyy-mm-dd")
        return value

    def validate_answersheet(self, value):
        # Kiểm tra template tồn tại và thuộc quyền quản lý của teacher
        teacher_id = self.context['request'].user.id
        template = AnswerSheetTemplate.objects(id=value, teacher_id=teacher_id).first()
        if not template:
            raise serializers.ValidationError("Template not found or you do not have permission to use it")
        return value

    def validate(self, data):
        # Kiểm tra teacher_id
        if 'teacher_id' in data:
            teacher = User.objects(id=data['teacher_id'], is_teacher=True).first()
            if not teacher:
                raise serializers.ValidationError("Teacher not found or is not a teacher")

        # Kiểm tra class_codes
        if 'class_codes' in data:
            for class_code in data['class_codes']:
                class_obj = Class.objects(class_code=class_code).first()
                if not class_obj:
                    raise serializers.ValidationError(f"Class with code {class_code} not found")

        return data

    def create(self, validated_data):
        # Add teacher_id from request
        validated_data['teacher_id'] = self.context['request'].user.id
        # Create exam
        exam = Exam(**validated_data)
        exam.save()
        return exam

    def update(self, instance, validated_data):
        # Update fields
        for field, value in validated_data.items():
            setattr(instance, field, value)
        instance.save()
        return instance
