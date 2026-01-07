from mongoengine import Document, StringField, IntField, ListField, DictField, DateTimeField
from datetime import datetime
from mongoengine.errors import ValidationError

class AnswerKey(Document):
    # Thông tin xác thực
    id_teacher = StringField(required=True)
    
    # Thông tin liên kết
    quiz_id = StringField(required=True)
    answersheet_id = StringField(required=True)
    
    # Thông tin từ answer sheet
    num_questions = IntField(required=True)
    num_exam_id = IntField(required=True)
    
    # Thông tin do người dùng nhập
    num_versions = IntField(required=True)
    
    # Timestamps
    created_at = DateTimeField(default=datetime.now)
    updated_at = DateTimeField(default=datetime.now)

    # Ngân hàng câu hỏi
    answer_bank = ListField(DictField(), required=True)
    # Format: {
    #   "question_code": "1",  # Thứ tự trong file
    #   "answer": "A"         # Đáp án
    # }

    # Danh sách mã đề
    versions = ListField(DictField())
    # Format: {
    #   "version_code": "001",
    #   "questions": [
    #     {
    #       "question_code": "3",
    #       "answer": "C",
    #       "order": 1
    #     },
    #     ...
    #   ]
    # }

    meta = {
        'collection': 'answer_keys',
        'indexes': [
            'quiz_id',
            'answersheet_id',
            'id_teacher'
        ],
        'ordering': ['-created_at']
    }

    def clean(self):
        # Validate số lượng version không vượt quá giới hạn của num_exam_id
        max_versions = 10 ** self.num_exam_id
        if self.num_versions > max_versions:
            raise ValidationError(f'Number of versions cannot exceed {max_versions}')
        
        # Validate số lượng câu hỏi trong answer_bank
        if len(self.answer_bank) < self.num_questions:
            raise ValidationError('Answer bank must contain at least num_questions questions')