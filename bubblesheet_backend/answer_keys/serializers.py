from rest_framework import serializers
from .models import AnswerKey

class AnswerKeySerializer(serializers.Serializer):
    id = serializers.CharField()
    id_teacher = serializers.CharField()
    quiz_id = serializers.CharField()
    answersheet_id = serializers.CharField()
    num_questions = serializers.IntegerField()
    num_versions = serializers.IntegerField()
    created_at = serializers.DateTimeField()
    updated_at = serializers.DateTimeField()
    answer_bank = serializers.ListField()
    versions = serializers.ListField()

    def to_representation(self, instance):
        return {
            'id': str(instance.id),
            'id_teacher': str(instance.id_teacher),
            'quiz_id': str(instance.quiz_id),
            'answersheet_id': str(instance.answersheet_id),
            'num_questions': instance.num_questions,
            'num_versions': instance.num_versions,
            'created_at': instance.created_at,
            'updated_at': instance.updated_at,
            'answer_bank': instance.answer_bank,
            'versions': instance.versions,
        }

class GenerateAnswerKeySerializer(serializers.Serializer):
    quiz_id = serializers.CharField(required=True)
    num_versions = serializers.IntegerField(required=True, min_value=1)
    answer_file = serializers.FileField(required=True)

    def validate_num_versions(self, value):
        # Validate số lượng version không quá lớn
        if value > 1000:  # Có thể điều chỉnh giới hạn
            raise serializers.ValidationError("Number of versions cannot exceed 1000")
        return value

    def validate_answer_file(self, value):
        # Validate file extension
        if not value.name.endswith(('.csv', '.txt')):
            raise serializers.ValidationError("File must be CSV or TXT")
        return value

class AnswerKeyDetailSerializer(serializers.Serializer):
    id = serializers.CharField()
    quiz_id = serializers.CharField()
    num_versions = serializers.IntegerField()
    num_questions = serializers.IntegerField()
    versions = serializers.ListField()
    created_at = serializers.DateTimeField()

    def to_representation(self, instance):
        return {
            'id': str(instance.id),
            'quiz_id': str(instance.quiz_id),
            'num_versions': instance.num_versions,
            'num_questions': instance.num_questions,
            'versions': instance.versions,
            'created_at': instance.created_at,
        } 