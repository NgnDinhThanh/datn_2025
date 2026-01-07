from mongoengine import Document, StringField, ObjectIdField, ListField, ValidationError, signals
from bson import ObjectId
from classes.models import Class
import logging

logger = logging.getLogger(__name__)

# Create your models here.
class Exam(Document):
    name = StringField(required=True)
    class_codes = ListField(StringField(), required=False)
    answersheet = StringField(required=True)
    date = StringField(required=True)
    teacher_id = ObjectIdField(required=True)

    meta = {
        'collection': 'exams',
        'indexes': ['teacher_id', 'class_codes']
    }

    def clean(self):
        from classes.models import Class  # Import động để tránh circular import
        from users.models import User

        # Validate teacher exists
        teacher = User.objects(id=self.teacher_id, is_teacher=True).first()
        if not teacher:
            raise ValidationError("Teacher not found or is not a teacher")

        # Validate class_codes if provided
        if self.class_codes:
            for class_code in self.class_codes:
                class_obj = Class.objects(class_code=class_code).first()
                if not class_obj:
                    raise ValidationError(f"Class with code {class_code} not found")

    def save(self, *args, **kwargs):
        try:
            # Lưu exam_id và class_codes cũ trước khi save
            old_exam = None
            if self.id:
                old_exam = Exam.objects(id=self.id).first()
            old_class_codes = set(old_exam.class_codes) if old_exam else set()
            new_class_codes = set(self.class_codes) if self.class_codes else set()

            # Lưu exam
            super().save(*args, **kwargs)
            logger.info(f"Saved exam {self.id}")

            # Thêm exam_id vào các class mới
            for class_code in new_class_codes - old_class_codes:
                try:
                    class_obj = Class.objects(class_code=class_code).first()
                    if class_obj and self.id not in class_obj.exam_ids:
                        class_obj.exam_ids.append(self.id)
                        class_obj.save()
                        logger.info(f"Added exam {self.id} to class {class_code}")
                except Exception as e:
                    logger.error(f"Error adding exam to class {class_code}: {str(e)}")
                    continue

            # Xóa exam_id khỏi các class cũ
            for class_code in old_class_codes - new_class_codes:
                try:
                    class_obj = Class.objects(class_code=class_code).first()
                    if class_obj and self.id in class_obj.exam_ids:
                        class_obj.exam_ids.remove(self.id)
                        class_obj.save()
                        logger.info(f"Removed exam {self.id} from class {class_code}")
                except Exception as e:
                    logger.error(f"Error removing exam from class {class_code}: {str(e)}")
                    continue

        except Exception as e:
            logger.error(f"Error saving exam {self.id}: {str(e)}")
            raise

    def delete(self, *args, **kwargs):
        try:
            # Xóa answer key liên quan đến quiz này
            from answer_keys.models import AnswerKey
            AnswerKey.objects.filter(quiz_id=str(self.id)).delete()
            # Lưu class_codes trước khi xóa
            class_codes_to_remove = list(self.class_codes) if self.class_codes else []
            exam_id = self.id

            # Xóa exam_ids trong các class trước
            for class_code in class_codes_to_remove:
                try:
                    class_obj = Class.objects(class_code=class_code).first()
                    if class_obj and exam_id in class_obj.exam_ids:
                        class_obj.exam_ids.remove(exam_id)
                        class_obj.save()
                        logger.info(f"Removed exam {exam_id} from class {class_code}")
                except Exception as e:
                    logger.error(f"Error removing exam from class {class_code}: {str(e)}")
                    continue

            # Xóa exam
            super().delete(*args, **kwargs)
            logger.info(f"Successfully deleted exam {exam_id}")

        except Exception as e:
            logger.error(f"Error deleting exam {self.id}: {str(e)}")
            raise
