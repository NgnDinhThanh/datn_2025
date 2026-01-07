"""
Simple test script for scanning API (no user input required)
"""
import os
import sys
import django
import requests
import json
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


def test_backend_connection():
    """Test if backend is running"""
    try:
        response = requests.get("http://127.0.0.1:8000/api/users/test/", timeout=5)
        if response.status_code == 200:
            print("[OK] Backend is running")
            return True
        else:
            print(f"[ERROR] Backend returned status {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("[ERROR] Cannot connect to backend")
        print("Please start backend: python manage.py runserver 0.0.0.0:8000")
        return False
    except Exception as e:
        print(f"[ERROR] Error: {e}")
        return False


def get_test_data():
    """Get test data from database"""
    print("\n" + "="*60)
    print("GETTING TEST DATA")
    print("="*60)
    
    # Get any quiz
    quiz = Quiz.objects.first()
    if not quiz:
        print("[ERROR] No quiz found in database")
        return None, None, None
    
    print(f"[OK] Found quiz: {quiz.name} (ID: {quiz.id})")
    
    # Get quiz owner
    quiz_owner = User.objects.filter(id=quiz.teacher_id).first()
    if quiz_owner:
        print(f"[OK] Quiz owner: {quiz_owner.email}")
    
    # Get answer sheet
    answersheet_id = quiz.answersheet
    answersheet = AnswerSheetTemplate.objects.filter(id=answersheet_id).first()
    if not answersheet:
        print(f"[ERROR] Answer sheet not found: {answersheet_id}")
        return quiz, None, quiz_owner
    
    print(f"[OK] Found answer sheet: {answersheet.name} (ID: {answersheet.id})")
    if answersheet.file_json and os.path.exists(answersheet.file_json):
        print(f"[OK] Template JSON exists: {answersheet.file_json}")
    else:
        print(f"[WARNING] Template JSON not found: {answersheet.file_json}")
    
    return quiz, answersheet, quiz_owner


def find_test_image():
    """Find a test image"""
    media_dir = settings.MEDIA_ROOT
    previews_dir = os.path.join(media_dir, 'answer_sheets', 'previews')
    
    if os.path.exists(previews_dir):
        for file in os.listdir(previews_dir):
            if file.endswith(('.jpg', '.jpeg', '.png')):
                return os.path.join(previews_dir, file)
    
    return None


def main():
    """Main test function"""
    print("="*60)
    print("TESTING SCANNING API - SIMPLE VERSION")
    print("="*60)
    print("\nThis script will:")
    print("1. Check if backend is running")
    print("2. Get test data from database")
    print("3. Show what you need to test manually")
    print("\nFor full testing, use: python test_scanning_api.py")
    print("="*60)
    
    # Check backend
    if not test_backend_connection():
        return
    
    # Get test data
    quiz, answersheet, quiz_owner = get_test_data()
    if not quiz or not answersheet:
        print("\n[ERROR] Cannot get test data")
        return
    
    # Find test image
    test_image = find_test_image()
    if test_image:
        print(f"\n[OK] Found test image: {test_image}")
    else:
        print("\n[WARNING] No test image found")
        print("Please provide a test image for testing")
    
    # Summary
    print("\n" + "="*60)
    print("TEST SETUP SUMMARY")
    print("="*60)
    print(f"Backend URL: http://127.0.0.1:8000")
    print(f"Quiz ID: {quiz.id}")
    print(f"Quiz Name: {quiz.name}")
    print(f"Answer Sheet ID: {answersheet.id}")
    print(f"Answer Sheet Name: {answersheet.name}")
    if quiz_owner:
        print(f"Quiz Owner: {quiz_owner.email}")
    if test_image:
        print(f"Test Image: {test_image}")
    
    print("\n" + "="*60)
    print("MANUAL TESTING STEPS")
    print("="*60)
    print("\n1. Get authentication token:")
    print(f"   POST http://127.0.0.1:8000/api/users/login/")
    print(f"   Body: {{'email': '{quiz_owner.email if quiz_owner else 'teacher@example.com'}', 'password': '...'}}")
    
    print("\n2. Test Preview Check:")
    print(f"   POST http://127.0.0.1:8000/api/grading/preview-check/")
    print(f"   Headers: Authorization: Bearer <token>")
    print(f"   Body (form-data): image: <file>")
    
    print("\n3. Test Scan & Grade:")
    print(f"   POST http://127.0.0.1:8000/api/grading/scan/")
    print(f"   Headers: Authorization: Bearer <token>")
    print(f"   Body (form-data):")
    print(f"     image: <file>")
    print(f"     quiz_id: {quiz.id}")
    print(f"     answersheet_id: {answersheet.id}")
    
    print("\n4. Test Save Grade:")
    print(f"   POST http://127.0.0.1:8000/api/grading/save-grade/")
    print(f"   Headers: Authorization: Bearer <token>")
    print(f"   Body (JSON): {{'quiz_id': '{quiz.id}', 'student_id': '...', 'score': 85, ...}}")
    
    print("\n" + "="*60)
    print("READY FOR TESTING!")
    print("="*60)
    print("\nUse Postman, curl, or test_scanning_api.py for full testing")


if __name__ == '__main__':
    main()





