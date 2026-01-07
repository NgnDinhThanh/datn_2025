from rest_framework import serializers
from bson import ObjectId


class GradeSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    class_code = serializers.CharField()
    exam_id = serializers.CharField()
    student_id = serializers.CharField()
    score = serializers.FloatField()
    answers = serializers.DictField()
    
    # New fields
    percentage = serializers.FloatField(required=False, allow_null=True)
    scanned_image = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    annotated_image = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    scanned_at = serializers.DateTimeField(required=False, allow_null=True)
    version_code = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    answersheet_id = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    teacher_id = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    created_at = serializers.DateTimeField(required=False, allow_null=True)
    updated_at = serializers.DateTimeField(required=False, allow_null=True)
    
    def to_representation(self, instance):
        """Convert MongoEngine Document to dict"""
        try:
            # Helper functions
            def safe_get_attr(attr_name, default=None):
                """Safely get attribute from instance"""
                try:
                    if hasattr(instance, attr_name):
                        value = getattr(instance, attr_name, default)
                        return value if value is not None else default
                    return default
                except Exception:
                    return default
            
            def safe_datetime(dt):
                """Safely convert datetime to ISO string"""
                try:
                    if dt and hasattr(dt, 'isoformat'):
                        return dt.isoformat()
                    return None
                except Exception:
                    return None
            
            def safe_str(value):
                """Safely convert value to string"""
                try:
                    if value is None:
                        return None
                    return str(value)
                except Exception:
                    return None
            
            # Get all fields safely
            data = {
                'id': safe_str(safe_get_attr('id')) or '',
                'class_code': safe_str(safe_get_attr('class_code')) or '',
                'exam_id': safe_str(safe_get_attr('exam_id')) or '',
                'student_id': safe_str(safe_get_attr('student_id')) or '',
                'score': safe_get_attr('score'),
                'answers': safe_get_attr('answers') or {},
                'percentage': safe_get_attr('percentage'),
                'scanned_image': safe_str(safe_get_attr('scanned_image')),
                'annotated_image': safe_str(safe_get_attr('annotated_image')),
                'scanned_at': safe_datetime(safe_get_attr('scanned_at')),
                'version_code': safe_str(safe_get_attr('version_code')),
                'answersheet_id': safe_str(safe_get_attr('answersheet_id')),
                'teacher_id': safe_str(safe_get_attr('teacher_id')),
                'created_at': safe_datetime(safe_get_attr('created_at')),
                'updated_at': safe_datetime(safe_get_attr('updated_at')),
            }
            return data
        except Exception as e:
            # Fallback: return minimal data if serialization fails
            import logging
            logger = logging.getLogger(__name__)
            grade_id = 'unknown'
            try:
                grade_id = str(getattr(instance, 'id', 'unknown'))
            except:
                pass
            logger.error(f"Error serializing grade {grade_id}: {str(e)}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            return {
                'id': grade_id if grade_id != 'unknown' else '',
                'class_code': '',
                'exam_id': '',
                'student_id': '',
                'score': None,
                'answers': {},
            }