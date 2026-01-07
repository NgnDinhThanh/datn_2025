"""
Test script for preview check only (no quiz required)
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
    print("\n" + "="*60)
    print("TESTING PREVIEW CHECK ENDPOINT")
    print("="*60)
    
    url = "http://127.0.0.1:8000/api/grading/preview-check/"
    headers = {'Authorization': f'Bearer {token}'}
    
    if not os.path.exists(image_path):
        print(f"[ERROR] Image file not found: {image_path}")
        return False
    
    print(f"Image: {image_path}")
    print(f"URL: {url}")
    print("Uploading image...")
    
    try:
        with open(image_path, 'rb') as f:
            files = {'image': f}
            response = requests.post(url, headers=headers, files=files, timeout=10)
        
        print(f"\nStatus Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print("[SUCCESS] Preview check successful!")
            print(f"\nResults:")
            print(f"  Ready: {data.get('ready')}")
            print(f"  Markers found: {len(data.get('markers', []))}")
            print(f"  Image size: {data.get('image_size', {}).get('width')}x{data.get('image_size', {}).get('height')}")
            
            # Show marker details
            markers = data.get('markers', [])
            if markers:
                print(f"\nMarker details:")
                for marker in markers:
                    marker_id = marker.get('id', '?')
                    position = marker.get('position', [])
                    print(f"  - Marker ID {marker_id}: position={position}")
            
            # Show normalized markers
            markers_norm = data.get('markers_norm', [])
            if markers_norm:
                print(f"\nNormalized markers:")
                for marker in markers_norm:
                    marker_id = marker.get('id', '?')
                    x = marker.get('x', 0)
                    y = marker.get('y', 0)
                    print(f"  - Marker ID {marker_id}: x={x:.3f}, y={y:.3f}")
            
            # Check if ready
            if data.get('ready'):
                print("\n[SUCCESS] Image is READY for scanning!")
                print("  All 4 corner markers (1, 5, 9, 10) are detected.")
            else:
                print("\n[WARNING] Image is NOT READY for scanning.")
                print("  Missing some corner markers.")
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


def find_test_images():
    """Find test images"""
    media_dir = settings.MEDIA_ROOT
    answer_sheets_dir = os.path.join(media_dir, 'answer_sheets')
    previews_dir = os.path.join(answer_sheets_dir, 'previews')
    
    test_images = []
    
    # Look in previews directory first
    if os.path.exists(previews_dir):
        for file in os.listdir(previews_dir):
            if file.endswith(('.jpg', '.jpeg', '.png')):
                test_images.append(os.path.join(previews_dir, file))
    
    # Look in answer_sheets directory
    if not test_images and os.path.exists(answer_sheets_dir):
        for file in os.listdir(answer_sheets_dir):
            if file.endswith(('.jpg', '.jpeg', '.png')):
                test_images.append(os.path.join(answer_sheets_dir, file))
    
    return test_images


def main():
    """Main test function"""
    print("="*60)
    print("TESTING PREVIEW CHECK ENDPOINT")
    print("="*60)
    
    # Check if backend is running
    print("\n[1] Checking if backend is running...")
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
    
    # Get teacher email
    print("\n[2] Getting authentication...")
    teacher_email = "vap@gmail.com"
    password = input(f"Enter password for {teacher_email} (or press Enter to skip): ").strip()
    
    token = None
    if password:
        token = get_auth_token(teacher_email, password)
        if token:
            print(f"[OK] Token obtained: {token[:20]}...")
        else:
            print("[WARNING] Cannot get token. Preview check requires authentication.")
            print("Skipping test...")
            return
    else:
        print("[SKIP] Skipping authentication test")
        return
    
    # Find test images
    print("\n[3] Finding test images...")
    test_images = find_test_images()
    
    if not test_images:
        print("[ERROR] No test images found")
        print("Please provide a test image path:")
        image_path = input("Image path: ").strip()
        if not image_path or not os.path.exists(image_path):
            print("[ERROR] Image file not found")
            return
        test_images = [image_path]
    else:
        print(f"[OK] Found {len(test_images)} test image(s)")
    
    # Test with first image
    test_image = test_images[0]
    print(f"\n[4] Testing with image: {test_image}")
    
    # Test preview check
    success = test_preview_check(token, test_image)
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    if success:
        print("[SUCCESS] Preview check test completed successfully!")
    else:
        print("[FAILED] Preview check test failed")
    print("="*60)


if __name__ == '__main__':
    main()





