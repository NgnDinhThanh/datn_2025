"""
Test script to check how quiz_id is stored in AnswerKey and how to query it
"""
import os
import sys
import django
from pathlib import Path

# Setup Django
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'bubblesheet_backend.settings')
django.setup()

from exams.models import Exam as Quiz
from answer_keys.models import AnswerKey

def test_answer_key_query():
    """Test how to query AnswerKey by quiz_id"""
    print("="*60)
    print("TESTING ANSWER KEY QUERY")
    print("="*60)
    
    # Get all quizzes
    quizzes = Quiz.objects.all()
    print(f"\n[1] Found {quizzes.count()} quizzes:")
    for quiz in quizzes[:5]:
        print(f"   - Quiz: {quiz.name}")
        print(f"     ID (raw): {quiz.id}")
        print(f"     ID (str): {str(quiz.id)}")
        print(f"     ID (type): {type(quiz.id)}")
        
        # Try different query formats
        quiz_id_str = str(quiz.id)
        
        # Query 1: Direct string
        ak1 = AnswerKey.objects(quiz_id=quiz_id_str).first()
        print(f"     Query with str(id): {'FOUND' if ak1 else 'NOT FOUND'}")
        
        # Query 2: Try with ObjectId format
        if ak1:
            print(f"     AnswerKey quiz_id (stored): {ak1.quiz_id}")
            print(f"     AnswerKey quiz_id (type): {type(ak1.quiz_id)}")
            print(f"     Match: {ak1.quiz_id == quiz_id_str}")
        
        # Query 3: Try all answer keys for this teacher
        if quiz.teacher_id:
            teacher_id_str = str(quiz.teacher_id)
            all_keys = AnswerKey.objects(id_teacher=teacher_id_str)
            print(f"     All answer keys for teacher: {all_keys.count()}")
            for ak in all_keys:
                print(f"       - AnswerKey quiz_id: {ak.quiz_id}, matches: {ak.quiz_id == quiz_id_str}")
        
        print()
    
    # Get all answer keys
    print(f"\n[2] Found {AnswerKey.objects.count()} answer keys:")
    for ak in AnswerKey.objects.all()[:5]:
        print(f"   - AnswerKey quiz_id: {ak.quiz_id}")
        print(f"     AnswerKey id_teacher: {ak.id_teacher}")
        # Try to find matching quiz
        quiz = Quiz.objects(id=ak.quiz_id).first()
        if quiz:
            print(f"     Matching quiz found: {quiz.name}")
        else:
            print(f"     No matching quiz found!")
        print()

if __name__ == '__main__':
    test_answer_key_query()


