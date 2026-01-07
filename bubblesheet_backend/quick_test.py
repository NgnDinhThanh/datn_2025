"""
Quick test script to check if backend is ready for testing
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

from django.conf import settings
from users.models import User
from exams.models import Exam as Quiz
from answer_sheets.models import AnswerSheetTemplate
from answer_keys.models import AnswerKey


def check_backend_readiness():
    """Check if backend is ready for testing"""
    import sys
    # Fix encoding for Windows
    if sys.platform == 'win32':
        import codecs
        sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
        sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')
    
    print("="*60)
    print("CHECKING BACKEND READINESS")
    print("="*60)
    
    issues = []
    
    # Check 1: Django setup
    print("\n[1] Checking Django setup...")
    try:
        from django.conf import settings
        print("   [OK] Django is configured")
    except Exception as e:
        print(f"   [ERROR] Django setup error: {e}")
        issues.append("Django setup")
    
    # Check 2: Database connection
    print("\n[2] Checking database connection...")
    try:
        from mongoengine import get_connection
        conn = get_connection()
        conn.server_info()
        print("   [OK] MongoDB connection OK")
    except Exception as e:
        print(f"   [ERROR] MongoDB connection error: {e}")
        issues.append("Database connection")
    
    # Check 3: Teacher user
    print("\n[3] Checking teacher user...")
    teacher = None
    try:
        teacher = User.objects.filter(is_teacher=True).first()
        if teacher:
            print(f"   [OK] Found teacher: {teacher.email}")
        else:
            print("   [WARNING] No teacher user found")
            issues.append("No teacher user")
    except Exception as e:
        print(f"   [ERROR] Error checking teacher: {e}")
        issues.append("Teacher user check")
    
    # Check 4: Quiz (Exam)
    print("\n[4] Checking quiz (exam)...")
    quiz = None
    try:
        if teacher:
            quiz = Quiz.objects.filter(teacher_id=teacher.id).first()
            if quiz:
                print(f"   [OK] Found quiz: {quiz.name} (ID: {quiz.id})")
            else:
                print("   [WARNING] No quiz found for this teacher")
                issues.append("No quiz")
        else:
            print("   [SKIP] Skipped (no teacher)")
    except Exception as e:
        print(f"   [ERROR] Error checking quiz: {e}")
        issues.append("Quiz check")
    
    # Check 5: Answer sheet template
    print("\n[5] Checking answer sheet template...")
    answersheet = None
    try:
        if teacher and quiz:
            answersheet_id = quiz.answersheet
            answersheet = AnswerSheetTemplate.objects.filter(id=answersheet_id).first()
            if answersheet:
                print(f"   [OK] Found answer sheet: {answersheet.name} (ID: {answersheet.id})")
                # Check template JSON file
                if answersheet.file_json and os.path.exists(answersheet.file_json):
                    print(f"   [OK] Template JSON exists: {answersheet.file_json}")
                else:
                    print(f"   [WARNING] Template JSON not found: {answersheet.file_json}")
                    issues.append("Template JSON file")
            else:
                print(f"   [WARNING] Answer sheet template not found: {answersheet_id}")
                issues.append("Answer sheet template")
        else:
            print("   [SKIP] Skipped (no teacher/quiz)")
    except Exception as e:
        print(f"   [ERROR] Error checking answer sheet: {e}")
        issues.append("Answer sheet check")
    
    # Check 6: Answer key
    print("\n[6] Checking answer key...")
    try:
        if teacher and quiz:
            answer_key = AnswerKey.objects.filter(
                quiz_id=str(quiz.id),
                id_teacher=str(teacher.id)
            ).first()
            if answer_key:
                print(f"   [OK] Found answer key with {len(answer_key.versions)} versions")
            else:
                print("   [WARNING] No answer key found (optional, but recommended)")
                issues.append("No answer key (optional)")
        else:
            print("   [SKIP] Skipped (no teacher/quiz)")
    except Exception as e:
        print(f"   [ERROR] Error checking answer key: {e}")
        issues.append("Answer key check")
    
    # Check 7: Media directories
    print("\n[7] Checking media directories...")
    try:
        grading_config = getattr(settings, 'GRADING_CONFIG', {})
        scanned_dir = grading_config.get('SCANNED_IMAGE_DIR')
        annotated_dir = grading_config.get('ANNOTATED_IMAGE_DIR')
        
        if scanned_dir:
            os.makedirs(scanned_dir, exist_ok=True)
            print(f"   [OK] Scanned images directory: {scanned_dir}")
        if annotated_dir:
            os.makedirs(annotated_dir, exist_ok=True)
            print(f"   [OK] Annotated images directory: {annotated_dir}")
    except Exception as e:
        print(f"   [ERROR] Error checking media directories: {e}")
        issues.append("Media directories")
    
    # Check 8: Test images
    print("\n[8] Checking test images...")
    try:
        media_dir = settings.MEDIA_ROOT
        answer_sheets_dir = os.path.join(media_dir, 'answer_sheets')
        previews_dir = os.path.join(answer_sheets_dir, 'previews')
        
        test_images = []
        if os.path.exists(previews_dir):
            for file in os.listdir(previews_dir):
                if file.endswith(('.jpg', '.jpeg', '.png')):
                    test_images.append(os.path.join(previews_dir, file))
        
        if test_images:
            print(f"   [OK] Found {len(test_images)} test image(s)")
            print(f"   Example: {test_images[0]}")
        else:
            print("   [WARNING] No test images found")
            print("   Tip: Use preview images from media/answer_sheets/previews/")
            issues.append("No test images (optional)")
    except Exception as e:
        print(f"   [ERROR] Error checking test images: {e}")
        issues.append("Test images check")
    
    # Check 9: OpenCV and NumPy
    print("\n[9] Checking dependencies...")
    try:
        import cv2
        import numpy as np
        print(f"   [OK] OpenCV version: {cv2.__version__}")
        print(f"   [OK] NumPy version: {np.__version__}")
    except ImportError as e:
        print(f"   [ERROR] Missing dependency: {e}")
        issues.append("Dependencies")
    
    # Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    
    critical_issues = [issue for issue in issues if "optional" not in issue.lower()]
    
    if not critical_issues:
        print("[SUCCESS] Backend is READY for testing!")
        print("\nNext steps:")
        print("   1. Start backend: python manage.py runserver 0.0.0.0:8000")
        print("   2. Run test script: python test_scanning_api.py")
    else:
        print("[WARNING] Backend has some issues:")
        for issue in critical_issues:
            print(f"   - {issue}")
        print("\nPlease fix the issues above before testing")
    
    print("="*60)


if __name__ == '__main__':
    check_backend_readiness()

