from rest_framework import serializers
from answer_sheets.models import AnswerSheetTemplate
from users.models import User
from datetime import datetime


class AnswerSheetTemplateSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    name = serializers.CharField(max_length=100)
    labels = serializers.ListField(
        child=serializers.CharField()
    )
    num_questions = serializers.IntegerField(min_value=1, max_value=100)
    num_options = serializers.IntegerField(min_value=2, max_value=5)
    student_id_digits = serializers.IntegerField(min_value=3, max_value=8)
    exam_id_digits = serializers.IntegerField(min_value=2, max_value=6)
    class_id_digits = serializers.IntegerField(min_value=2, max_value=6)
    teacher_id = serializers.CharField(read_only=True)  # Changed back to teacher_id
    created_at = serializers.CharField(read_only=True)  # Will be set automatically
    updated_at = serializers.CharField(read_only=True)  # Will be set automatically
    file_pdf = serializers.CharField(allow_null=True, required=False)
    file_json = serializers.CharField(allow_null=True, required=False)
    file_png = serializers.CharField(allow_null=True, required=False)
    preview_image = serializers.CharField(allow_null=True, required=False)

    def validate_name(self, value):
        if AnswerSheetTemplate.objects(name=value).first():
            raise serializers.ValidationError("Template with this name already exists")
        return value

    def validate_labels(self, value):
        if not value:
            raise serializers.ValidationError("Labels are required")
        for label in value:
            if not isinstance(label, str):
                raise serializers.ValidationError("Each label must be a string")
        return value

    def validate(self, data):
        # Additional validation that requires multiple fields
        if data.get('num_questions', 0) > 100:
            raise serializers.ValidationError("Number of questions cannot exceed 100")
        if data.get('num_options', 0) > 5:
            raise serializers.ValidationError("Number of options cannot exceed 5")
        return data

    def create(self, validated_data):
        # Add teacher_id from request
        validated_data['teacher_id'] = self.context['request'].user.id
        # Không gán file_pdf, file_json tạm thời ở đây
        validated_data['created_at'] = datetime.now().isoformat()
        validated_data['updated_at'] = datetime.now().isoformat()
        # Create template
        template = AnswerSheetTemplate(**validated_data)
        template.save()
        return template

    def update(self, instance, validated_data):
        # Update fields
        for field, value in validated_data.items():
            setattr(instance, field, value)
        instance.save()
        return instance