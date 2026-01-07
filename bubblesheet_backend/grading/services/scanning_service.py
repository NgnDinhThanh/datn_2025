"""
Service for scanning and grading answer sheets
"""
import os
import base64
from typing import Dict, Optional, List, Tuple
from answer_sheets.models import AnswerSheetTemplate
from answer_keys.models import AnswerKey
from grading.grade_pipeline import (
    process_answer_sheet,
    detect_aruco,
    ARUCO_TYPE,
    encode_image_base64
)
import cv2
import numpy as np


def quiz_id_to_version_code(quiz_id_digits: List[int], num_exam_id: int) -> str:
    """
    Convert quiz ID digits to version code
    
    Args:
        quiz_id_digits: List[int] like [0, 0, 1]
        num_exam_id: int like 3 (number of digits)
    
    Returns:
        str: Version code like "001"
    """
    version_code = ''.join(map(str, quiz_id_digits))
    version_code = version_code.zfill(num_exam_id)
    return version_code


def get_answer_key_for_version(
    answer_key_obj: AnswerKey,
    version_code: str
) -> Optional[Dict[int, int]]:
    """
    Get answer key dict for specific version
    
    Args:
        answer_key_obj: AnswerKey object
        version_code: String like "001"
    
    Returns:
        dict: {question_index: answer_index} or None if not found
    """
    # Find version matching version_code
    version = next(
        (v for v in answer_key_obj.versions if v.get('version_code') == version_code),
        None
    )
    
    if not version:
        return None
    
    # Convert questions to answer key dict
    answer_key_dict = {}
    questions = version.get('questions', [])
    for q in questions:
        order = q.get('order', 0) - 1  # Convert to 0-based index
        answer = q.get('answer', '')  # "A", "B", "C", "D", "E"
        if answer and len(answer) > 0:
            answer_index = ord(answer.upper()) - ord('A')  # A=0, B=1, C=2, D=3, E=4
            answer_key_dict[order] = answer_index
    
    return answer_key_dict


def grade_answers_with_key(
    answer_key_dict: Dict[int, int],
    student_answers: Dict[str, object],
    num_questions: Optional[int] = None,
) -> Tuple[int, int, float]:
    """
    Grade student answers using provided answer key.

    Args:
        answer_key_dict: {question_index (0-based): correct_answer_index}
        student_answers: dict like {"1": "A", "2": 1, "3": [0], ...}
        num_questions: optional total number of questions. If None, will use
            max index from answer_key_dict or student_answers.

    Returns:
        (score, total_questions, percentage)
    """
    if not isinstance(student_answers, dict):
        student_answers = {}

    # Determine total questions
    max_idx = -1
    if answer_key_dict:
        max_idx = max(max_idx, max(answer_key_dict.keys()))

    for key in student_answers.keys():
        try:
            q_idx_1_based = int(str(key))
            max_idx = max(max_idx, q_idx_1_based - 1)
        except (TypeError, ValueError):
            continue

    if num_questions is not None and num_questions > 0:
        total_questions = num_questions
    else:
        total_questions = max_idx + 1 if max_idx >= 0 else 0

    score = 0

    # Helper to normalize student answer to index
    def _to_index(value) -> Optional[int]:
        if value is None:
            return None
        # list -> lấy phần tử đầu
        if isinstance(value, list) and value:
            value = value[0]
        # int -> dùng trực tiếp
        if isinstance(value, int):
            return value
        # string
        if isinstance(value, str):
            v = value.strip()
            if not v:
                return None
            # thử parse số
            try:
                return int(v)
            except ValueError:
                # coi như chữ cái A/B/C...
                ch = v.upper()[0]
                if "A" <= ch <= "Z":
                    return ord(ch) - ord("A")
        return None

    for q_idx_0_based, correct_idx in answer_key_dict.items():
        # convert 0-based index to "1", "2", ...
        q_key = str(q_idx_0_based + 1)
        student_val = student_answers.get(q_key)
        student_idx = _to_index(student_val)

        if student_idx is not None and correct_idx is not None and student_idx == correct_idx:
            score += 1

    percentage = (score / total_questions * 100.0) if total_questions > 0 else 0.0
    return score, total_questions, percentage


def scan_and_grade(
    image_path: str,
    quiz_id: str,
    answersheet_id: str,
    teacher_id: str
) -> Dict:
    """
    Scan and grade answer sheet
    
    Args:
        image_path: Path to image file
        quiz_id: Quiz ID (Exam.id)
        answersheet_id: AnswerSheetTemplate ID
        teacher_id: Teacher ID
    
    Returns:
        dict: {
            'success': bool,
            'score': int,
            'total_questions': int,
            'percentage': float,
            'student_id': str,
            'quiz_id': str,
            'class_id': str,
            'answers': dict,
            'version_code': str,
            'annotated_image_base64': str,
            'error': str,  # Optional
        }
    """
    try:
        # 1. Load AnswerSheetTemplate
        template = AnswerSheetTemplate.objects.get(id=answersheet_id)
        if str(template.teacher_id) != str(teacher_id):
            raise PermissionError('You do not have permission to access this answer sheet template')
        
        if not template.file_json or not os.path.exists(template.file_json):
            raise ValueError(f'Template JSON file not found: {template.file_json}')
        
        template_json_path = template.file_json
        
        # 2. Load AnswerKey
        answer_key_obj = AnswerKey.objects.get(
            quiz_id=quiz_id,
            id_teacher=str(teacher_id)
        )
        
        # 3. Process image (read IDs first, without grading)
        result = process_answer_sheet(
            image_path=image_path,
            template_json_path=template_json_path,
            answer_key_dict=None,  # Don't grade yet
            save_warped=False,
        )
        
        # 4. Convert quiz_id to version_code
        quiz_id_digits = result['quiz_id']  # List[int]
        if not quiz_id_digits:
            return {
                'success': False,
                'error': 'Failed to read quiz ID from answer sheet',
            }
        
        version_code = quiz_id_to_version_code(
            quiz_id_digits,
            answer_key_obj.num_exam_id
        )
        
        # 5. Get answer key for version
        answer_key_dict = get_answer_key_for_version(
            answer_key_obj,
            version_code
        )
        
        # 6. Process image again with answer key (if found)
        if answer_key_dict is None:
            # Version not found → score = 0
            # Use result from first process (already has answers)
            student_id_str = ''.join(map(str, result['student_id'])) if result['student_id'] else ''
            quiz_id_str = ''.join(map(str, result['quiz_id'])) if result['quiz_id'] else ''
            class_id_str = ''.join(map(str, result['class_id'])) if result['class_id'] else None
            
            # Create annotated image (without grading circles, but with answers read)
            annotated_img = result['annotated_image']
            annotated_image_base64 = encode_image_base64(annotated_img)
            
            return {
                'success': True,
                'score': 0,
                'total_questions': result['total_questions'],
                'percentage': 0.0,
                'student_id': student_id_str,
                'quiz_id': quiz_id_str,
                'class_id': class_id_str,
                'answers': result.get('answers', {}),
                'version_code': version_code,
                'error': f'Version code {version_code} not found in answer key',
                'annotated_image_base64': annotated_image_base64,
            }
        
        # 7. Grade with answer key (process again with answer key)
        result = process_answer_sheet(
            image_path=image_path,
            template_json_path=template_json_path,
            answer_key_dict=answer_key_dict,
            save_warped=False,
        )
        
        # 8. Convert IDs to strings
        student_id_str = ''.join(map(str, result['student_id'])) if result['student_id'] else ''
        quiz_id_str = ''.join(map(str, result['quiz_id'])) if result['quiz_id'] else ''
        class_id_str = ''.join(map(str, result['class_id'])) if result['class_id'] else None
        
        # 9. Encode annotated image to base64
        annotated_image_base64 = None
        if 'annotated_image' in result:
            annotated_image_base64 = encode_image_base64(result['annotated_image'])
        
        # 10. Return result
        return {
            'success': True,
            'score': result['score'],
            'total_questions': result['total_questions'],
            'percentage': result['percentage'],
            'student_id': student_id_str,
            'quiz_id': quiz_id_str,
            'class_id': class_id_str,
            'answers': result.get('answers', {}),
            'version_code': version_code,
            'annotated_image_base64': annotated_image_base64,
        }
        
    except AnswerSheetTemplate.DoesNotExist:
        return {
            'success': False,
            'error': f'Answer sheet template with id {answersheet_id} not found',
        }
    except AnswerKey.DoesNotExist:
        return {
            'success': False,
            'error': f'Answer key not found for quiz {quiz_id}',
        }
    except PermissionError as e:
        return {
            'success': False,
            'error': str(e),
        }
    except ValueError as e:
        return {
            'success': False,
            'error': str(e),
        }
    except Exception as e:
        return {
            'success': False,
            'error': f'Processing failed: {str(e)}',
        }


def preview_check(image_path: str) -> Dict:
    """
    Preview check for ArUco markers
    
    Args:
        image_path: Path to image file
    
    Returns:
        dict: {
            'ready': bool,
            'markers': List[Dict],
            'markers_norm': List[Dict],
            'image_size': Dict,
            'error': str,  # Optional
        }
    """
    try:
        # Load image
        img = cv2.imread(image_path)
        if img is None:
            return {
                'ready': False,
                'error': 'Invalid image data',
                'markers': [],
                'markers_norm': [],
                'image_size': {'width': 0, 'height': 0},
            }
        
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Detect ArUco markers
        markers = detect_aruco(gray, ARUCO_TYPE)
        
        # Normalize marker positions
        h, w = gray.shape[:2]
        markers_norm = [
            {
                'id': m['id'],
                'x': float(m['position'][0]) / float(w if w else 1),
                'y': float(m['position'][1]) / float(h if h else 1),
            }
            for m in markers
        ]
        
        # Check if ready (chỉ cần có ít nhất 1 marker để xác định có phải phiếu không)
        # Không cần đủ 4 điểm, chỉ cần có ít nhất 1 điểm ArUco
        ready = len(markers) > 0
        
        return {
            'ready': ready,
            'markers': markers,
            'markers_norm': markers_norm,
            'image_size': {'width': w, 'height': h},
        }
        
    except Exception as e:
        return {
            'ready': False,
            'error': str(e),
            'markers': [],
            'markers_norm': [],
            'image_size': {'width': 0, 'height': 0},
        }

