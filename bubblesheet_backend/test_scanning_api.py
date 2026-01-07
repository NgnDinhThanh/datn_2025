"""
Test script for scanning API endpoints
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
from answer_keys.models import AnswerKey


def get_auth_token(email, password):
    """Get authentication token"""
    url = f"http://127.0.0.1:8000/api/users/login/"
    try:
        response = requests.post(url, json={
            'email': email,
            'password': password
        }, timeout=5)
        if response.status_code == 200:
            data = response.json()
            return data.get('token')
        else:
            print(f"[ERROR] Login failed: {response.status_code} - {response.text}")
            return None
    except requests.exceptions.ConnectionError:
        print("[ERROR] Cannot connect to backend. Please start server:")
        print("   python manage.py runserver 0.0.0.0:8000")
        return None
    except Exception as e:
        print(f"[ERROR] Login error: {e}")
        return None


def test_preview_check(token, image_path):
    """Test preview check endpoint"""
    url = "http://127.0.0.1:8000/api/grading/preview-check/"
    headers = {'Authorization': f'Bearer {token}'}
    
    if not os.path.exists(image_path):
        print(f"[ERROR] Image file not found: {image_path}")
        return False
    
    try:
        with open(image_path, 'rb') as f:
            files = {'image': f}
            response = requests.post(url, headers=headers, files=files, timeout=10)
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"[SUCCESS] Preview check successful!")
            print(f"  Ready: {data.get('ready')}")
            print(f"  Markers found: {len(data.get('markers', []))}")
            print(f"  Image size: {data.get('image_size', {}).get('width')}x{data.get('image_size', {}).get('height')}")
            
            # Show marker details
            markers = data.get('markers', [])
            if markers:
                print(f"\nMarker details:")
                for marker in markers[:5]:  # Show first 5
                    marker_id = marker.get('id', '?')
                    position = marker.get('position', [])
                    print(f"  - Marker ID {marker_id}: position={position}")
            
            if data.get('error'):
                print(f"  Error: {data.get('error')}")
            
            return True
        else:
            print(f"[ERROR] Preview check failed: {response.status_code}")
            try:
                error_data = response.json()
                print(f"Response: {json.dumps(error_data, indent=2)}")
            except:
                print(f"Response: {response.text}")
            return False
    except FileNotFoundError:
        print(f"[ERROR] Image file not found: {image_path}")
        return False
    except Exception as e:
        print(f"[ERROR] Error: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_scan_and_grade(token, image_path, quiz_id, answersheet_id):
    """Test scan and grade endpoint"""
    url = "http://127.0.0.1:8000/api/grading/scan/"
    headers = {'Authorization': f'Bearer {token}'}
    
    if not os.path.exists(image_path):
        print(f"[ERROR] Image file not found: {image_path}")
        return None
    
    print(f"Image: {image_path}")
    print(f"Quiz ID: {quiz_id}")
    print(f"Answer Sheet ID: {answersheet_id}")
    print("Processing... (this may take 30-60 seconds)")
    
    try:
        with open(image_path, 'rb') as f:
            files = {'image': f}
            data = {
                'quiz_id': quiz_id,
                'answersheet_id': answersheet_id
            }
            response = requests.post(url, headers=headers, files=files, data=data, timeout=60)
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"[SUCCESS] Scan & grade successful!")
            print(f"  Success: {result.get('success')}")
            print(f"  Score: {result.get('score')}/{result.get('total_questions')}")
            print(f"  Percentage: {result.get('percentage')}%")
            print(f"  Student ID: {result.get('student_id')}")
            print(f"  Quiz ID: {result.get('quiz_id')}")
            print(f"  Class ID: {result.get('class_id')}")
            print(f"  Version Code: {result.get('version_code')}")
            print(f"  Answers: {len(result.get('answers', {}))} answers read")
            if result.get('error'):
                print(f"  Warning: {result.get('error')}")
            if result.get('annotated_image_base64'):
                print(f"  Annotated image: {len(result.get('annotated_image_base64'))} bytes (base64)")
            return result
        else:
            print(f"[ERROR] Scan & grade failed: {response.status_code}")
            try:
                error_data = response.json()
                print(f"Response: {json.dumps(error_data, indent=2)}")
            except:
                print(f"Response: {response.text}")
            return None
    except FileNotFoundError:
        print(f"[ERROR] Image file not found: {image_path}")
        return None
    except Exception as e:
        print(f"[ERROR] Error: {e}")
        import traceback
        traceback.print_exc()
        return None


def test_save_grade(token, grade_data):
    """Test save grade endpoint"""
    url = "http://127.0.0.1:8000/api/grading/save-grade/"
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    print(f"Grade data:")
    print(f"  Quiz ID: {grade_data.get('quiz_id')}")
    print(f"  Student ID: {grade_data.get('student_id')}")
    print(f"  Score: {grade_data.get('score')}/{grade_data.get('total_questions', '?')}")
    print(f"  Percentage: {grade_data.get('percentage')}%")
    
    try:
        response = requests.post(url, headers=headers, json=grade_data, timeout=30)
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 201:
            result = response.json()
            print(f"[SUCCESS] Save grade successful!")
            print(f"  Grade ID: {result.get('grade_id')}")
            return result
        else:
            print(f"[ERROR] Save grade failed: {response.status_code}")
            try:
                error_data = response.json()
                print(f"Response: {json.dumps(error_data, indent=2)}")
            except:
                print(f"Response: {response.text}")
            return None
    except Exception as e:
        print(f"[ERROR] Error: {e}")
        import traceback
        traceback.print_exc()
        return None


def get_test_data(teacher_email=None):
    """Get test data from database"""
    print("\n" + "="*50)
    print("Getting test data from database")
    print("="*50)
    
    try:
        # Get a teacher user
        if teacher_email:
            teacher = User.objects.filter(email=teacher_email, is_teacher=True).first()
            if not teacher:
                print(f"[WARNING] Teacher {teacher_email} not found, using any teacher")
                teacher = User.objects.filter(is_teacher=True).first()
        else:
            teacher = User.objects.filter(is_teacher=True).first()
        
        if not teacher:
            print("[ERROR] No teacher found in database")
            return None, None, None, None
        
        print(f"[OK] Found teacher: {teacher.email} (ID: {teacher.id})")
        
        # Get a quiz (exam) - try teacher's quiz first, then any quiz
        quiz = Quiz.objects.filter(teacher_id=teacher.id).first()
        if not quiz:
            print(f"[WARNING] No quiz found for teacher {teacher.email}")
            print("[INFO] Looking for any quiz in database...")
            quiz = Quiz.objects.first()
        
        if not quiz:
            print("[ERROR] No quiz found in database")
            return teacher, None, None, None
        
        # Check if quiz belongs to different teacher
        if str(quiz.teacher_id) != str(teacher.id):
            print(f"[WARNING] Quiz belongs to different teacher")
            print(f"[INFO] Using quiz: {quiz.name} (ID: {quiz.id})")
            print(f"[INFO] Quiz teacher ID: {quiz.teacher_id}")
            print(f"[INFO] Current teacher ID: {teacher.id}")
            print("[INFO] You may need to use the quiz owner's credentials for full testing")
        
        print(f"[OK] Found quiz: {quiz.name} (ID: {quiz.id})")
        
        # Get answer sheet template
        answersheet_id = quiz.answersheet
        answersheet = AnswerSheetTemplate.objects.filter(id=answersheet_id).first()
        if not answersheet:
            print(f"[ERROR] Answer sheet template not found: {answersheet_id}")
            return teacher, quiz, None, None
        
        print(f"[OK] Found answer sheet: {answersheet.name} (ID: {answersheet.id})")
        print(f"   Template JSON: {answersheet.file_json}")
        
        # Check if template JSON exists
        if not answersheet.file_json or not os.path.exists(answersheet.file_json):
            print(f"[WARNING] Template JSON file not found: {answersheet.file_json}")
        else:
            print(f"[OK] Template JSON file exists")
        
        # Get answer key (try with quiz owner's ID first, then current teacher)
        answer_key = AnswerKey.objects.filter(
            quiz_id=str(quiz.id),
            id_teacher=str(quiz.teacher_id)
        ).first()
        
        if not answer_key:
            answer_key = AnswerKey.objects.filter(
                quiz_id=str(quiz.id),
                id_teacher=str(teacher.id)
            ).first()
        
        if not answer_key:
            print(f"[WARNING] No answer key found for quiz {quiz.id}")
            print("[INFO] Scanning will work but grading may return score 0 if version not found")
        else:
            print(f"[OK] Found answer key with {len(answer_key.versions)} versions")
            print(f"   Answer key teacher ID: {answer_key.id_teacher}")
        
        return teacher, quiz, answersheet, answer_key
        
    except Exception as e:
        print(f"[ERROR] Error getting test data: {e}")
        import traceback
        traceback.print_exc()
        return None, None, None, None


def main():
    """Main test function"""
    print("="*60)
    print("TESTING SCANNING API ENDPOINTS")
    print("="*60)
    
    # Check if backend is running
    try:
        response = requests.get("http://127.0.0.1:8000/api/users/test/", timeout=5)
        if response.status_code != 200:
            print("[ERROR] Backend is not running or not accessible")
            print("Please start backend: python manage.py runserver 0.0.0.0:8000")
            return
        print("[OK] Backend is running")
    except requests.exceptions.ConnectionError:
        print("[ERROR] Cannot connect to backend")
        print("Please start backend: python manage.py runserver 0.0.0.0:8000")
        return
    except Exception as e:
        print(f"[ERROR] Error checking backend: {e}")
        return
    
    # Get test data
    teacher, quiz, answersheet, answer_key = get_test_data()
    if not teacher:
        print("[ERROR] Cannot get test data. Please check database.")
        return
    
    if not quiz:
        print("[ERROR] No quiz found. Please create a quiz first.")
        return
    
    if not answersheet:
        print("[ERROR] No answer sheet found. Please create an answer sheet first.")
        return
    
    # Get auth token
    print("\n" + "="*50)
    print("Getting authentication token")
    print("="*50)
    
    # Check if quiz belongs to different teacher
    quiz_owner_email = None
    if str(quiz.teacher_id) != str(teacher.id):
        quiz_owner = User.objects.filter(id=quiz.teacher_id).first()
        if quiz_owner:
            quiz_owner_email = quiz_owner.email
            print(f"[INFO] Quiz belongs to: {quiz_owner_email}")
            print(f"[INFO] Current teacher: {teacher.email}")
            print(f"[INFO] You may want to use {quiz_owner_email} credentials for full access")
    
    # Try to get password from user or use default
    email_to_use = quiz_owner_email if quiz_owner_email else teacher.email
    password = input(f"Enter password for {email_to_use} (or press Enter to skip): ").strip()
    if not password:
        print("[SKIP] Skipping authentication test")
        token = None
    else:
        token = get_auth_token(email_to_use, password)
        if not token:
            print("[ERROR] Cannot get token. Please check credentials.")
            print("[INFO] You can still test preview check without authentication")
            token = None
        else:
            print(f"[OK] Token obtained: {token[:20]}...")
    
    # Test image path
    # Look for test images in media/answer_sheets/previews
    test_image_path = None
    media_dir = settings.MEDIA_ROOT
    answer_sheets_dir = os.path.join(media_dir, 'answer_sheets')
    previews_dir = os.path.join(answer_sheets_dir, 'previews')
    
    # Try to find any image file in previews directory
    if os.path.exists(previews_dir):
        for file in os.listdir(previews_dir):
            if file.endswith(('.jpg', '.jpeg', '.png')):
                test_image_path = os.path.join(previews_dir, file)
                break
    
    # If no preview image, try answer_sheets directory
    if not test_image_path and os.path.exists(answer_sheets_dir):
        for file in os.listdir(answer_sheets_dir):
            if file.endswith(('.jpg', '.jpeg', '.png')):
                test_image_path = os.path.join(answer_sheets_dir, file)
                break
    
    if not test_image_path:
        print("\n[WARNING] No test image found in media/answer_sheets/")
        print("Please provide a test image path:")
        test_image_path = input("Image path: ").strip()
        if not test_image_path or not os.path.exists(test_image_path):
            print("[ERROR] Image file not found. Cannot test scanning.")
            print("\nTip: You can use a preview image from media/answer_sheets/previews/")
            print("Or use any answer sheet image with ArUco markers")
            return
    
    print(f"\n[OK] Using test image: {test_image_path}")
    
    # Test endpoints
    if token:
        # Test 1: Preview check
        print("\n" + "="*60)
        print("TEST 1: PREVIEW CHECK")
        print("="*60)
        preview_success = test_preview_check(token, test_image_path)
        
        if preview_success:
            # Test 2: Scan & grade
            print("\n" + "="*60)
            print("TEST 2: SCAN & GRADE")
            print("="*60)
            scan_result = test_scan_and_grade(
                token,
                test_image_path,
                str(quiz.id),
                str(answersheet.id)
            )
            
            # Test 3: Save grade (if scan was successful)
            if scan_result and scan_result.get('success'):
                print("\n" + "="*60)
                print("TEST 3: SAVE GRADE")
                print("="*60)
                grade_data = {
                    'quiz_id': str(quiz.id),
                    'student_id': scan_result.get('student_id', '123456'),
                    'score': scan_result.get('score', 0),
                    'percentage': scan_result.get('percentage', 0.0),
                    'answers': scan_result.get('answers', {}),
                    'version_code': scan_result.get('version_code', ''),
                    'answersheet_id': str(answersheet.id),
                }
                
                # Add class_id if available
                if scan_result.get('class_id'):
                    grade_data['class_id'] = scan_result.get('class_id')
                elif quiz.class_codes:
                    # Use first class code
                    from classes.models import Class
                    class_obj = Class.objects.filter(class_code=quiz.class_codes[0]).first()
                    if class_obj:
                        grade_data['class_id'] = str(class_obj.id)
                
                test_save_grade(token, grade_data)
            else:
                print("\n[SKIP] Skipping save grade test (scan failed)")
        else:
            print("\n[WARNING] Preview check failed. Scan & grade may also fail.")
            print("[INFO] You can still try scan & grade if you want")
            try_scan = input("Try scan & grade anyway? (y/n): ").strip().lower()
            if try_scan == 'y':
                scan_result = test_scan_and_grade(
                    token,
                    test_image_path,
                    str(quiz.id),
                    str(answersheet.id)
                )
    else:
        print("\n[SKIP] Skipping API tests (no token)")
        print("[INFO] Preview check and scan & grade require authentication")
    
    print("\n" + "="*60)
    print("TESTING COMPLETED")
    print("="*60)


if __name__ == '__main__':
    main()

