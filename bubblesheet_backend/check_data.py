"""
Check existing data in database
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

from users.models import User
from exams.models import Exam as Quiz
from answer_sheets.models import AnswerSheetTemplate
from answer_keys.models import AnswerKey


def check_data():
    """Check existing data"""
    print("="*60)
    print("CHECKING DATABASE DATA")
    print("="*60)
    
    # Check teachers
    print("\n[1] Teachers:")
    teachers = User.objects.filter(is_teacher=True)
    print(f"   Total: {teachers.count()}")
    for teacher in teachers:
        print(f"   - {teacher.email} (ID: {teacher.id})")
    
    # Check quizzes
    print("\n[2] Quizzes (Exams):")
    quizzes = Quiz.objects.all()
    print(f"   Total: {quizzes.count()}")
    if quizzes.count() > 0:
        for quiz in quizzes[:5]:
            print(f"   - {quiz.name} (ID: {quiz.id}, Teacher: {quiz.teacher_id})")
            if quiz.answersheet:
                print(f"     Answer Sheet ID: {quiz.answersheet}")
    
    # Check answer sheets
    print("\n[3] Answer Sheet Templates:")
    templates = AnswerSheetTemplate.objects.all()
    print(f"   Total: {templates.count()}")
    if templates.count() > 0:
        for template in templates[:5]:
            json_exists = "YES" if (template.file_json and os.path.exists(template.file_json)) else "NO"
            print(f"   - {template.name} (ID: {template.id})")
            print(f"     JSON file: {json_exists}")
            if template.file_json:
                print(f"     Path: {template.file_json}")
    
    # Check answer keys
    print("\n[4] Answer Keys:")
    answer_keys = AnswerKey.objects.all()
    print(f"   Total: {answer_keys.count()}")
    if answer_keys.count() > 0:
        for ak in answer_keys[:5]:
            print(f"   - Quiz ID: {ak.quiz_id}, Versions: {len(ak.versions)}")
    
    # Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    
    if quizzes.count() > 0:
        print("[OK] Found quizzes in database")
        print("\nWe can test with existing data!")
    else:
        print("[WARNING] No quizzes found")
        print("\nWe can still test preview check (no quiz required)")
        print("For full testing, we need:")
        print("  1. A quiz")
        print("  2. An answer sheet template with JSON file")
        print("  3. An answer key (optional)")
    
    print("="*60)


if __name__ == '__main__':
    check_data()





