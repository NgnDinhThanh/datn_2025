import cv2
import numpy as np
import json
import base64
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from .aruco_dict import ARUCO_DICT

# --- Cấu hình chung ---
ARUCO_TYPE = 'DICT_4X4_50'

# Ngưỡng pixel tô
MIN_ANSWER_PIXELS = 1200
MIN_ID_PIXELS = {
    'student': 700,
    'quiz': 600,
    'class': 600
}

# Màu vẽ
COLORS = {
    'correct': (0, 255, 0),
    'wrong': (0, 0, 255),
    'highlight': (0, 255, 255),
    'text': (0, 0, 255)
}
FONT = cv2.FONT_HERSHEY_SIMPLEX


def load_data(img_path, json_path):
    img = cv2.imread(img_path)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    with open(json_path, 'r') as f:
        data = json.load(f)
    return img, gray, data


def detect_aruco(gray, aruco_type):
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    gray = clahe.apply(blurred)
    arucoDict = cv2.aruco.getPredefinedDictionary(ARUCO_DICT[aruco_type])
    arucoParams = cv2.aruco.DetectorParameters()
    arucoDetector = cv2.aruco.ArucoDetector(arucoDict, arucoParams)
    (corners, ids, _) = arucoDetector.detectMarkers(gray)
    positions = []
    if ids is not None:
        ids = ids.flatten()
        for markerCorner, markerID in zip(corners, ids):
            corners_reshaped = markerCorner.reshape((4, 2))
            (topLeft, topRight, bottomRight, bottomLeft) = corners_reshaped
            cX = int((topLeft[0] + bottomRight[0]) / 2.0)
            cY = int((topLeft[1] + bottomRight[1]) / 2.0)

            positions.append({'id': int(markerID), 'position': [cX, cY]})
    return positions


def warp_to_template(img, detected, template_markers, output_size=(2481, 3508)):
    """
    Warp image to template using ArUco markers
    
    Args:
        img: Input image
        detected: Detected ArUco markers from image
        template_markers: Template markers from JSON
        output_size: Output image size (width, height)
    
    Returns:
        warped: Warped image
    """
    input_points, template_points = [], []

    for marker in template_markers:
        marker_id = marker["id"]

        matching_marker = next((m for m in detected if m["id"] == marker_id), None)
        if matching_marker:
            input_points.append(matching_marker["position"])
            template_points.append(marker["position"])

    if len(input_points) < 4:
        raise ValueError(f"Not enough markers found. Need 4, found {len(input_points)}")

    input_points = np.array(input_points, dtype=np.float32)
    template_points = np.array(template_points, dtype=np.float32)

    H, _ = cv2.findHomography(input_points, template_points, cv2.RANSAC)
    (w, h) = output_size
    warped = cv2.warpPerspective(img, H, (w, h))
    return warped


def verify_warp(image, data):
    # Vẽ marker
    for m in data['aruco_marker']:
        cx, cy = m['position']
        r = m.get('size', 50) // 2
        pts = [(cx - r, cy - r), (cx + r, cy - r), (cx + r, cy + r), (cx - r, cy + r)]
        for i in range(4):
            cv2.line(image, pts[i], pts[(i + 1) % 4], COLORS['wrong'], 2)
        cv2.putText(image, str(m['id']), (cx - 10, cy - 10), FONT, 0.5, COLORS['wrong'], 1)
    # Vẽ vùng info, student, quiz, class, answer
    colors = {
        'info_section': (0, 255, 0),
        'student_id_section': (255, 0, 0),
        'quiz_id_section': (0, 0, 255),
        'class_id_section': (0, 255, 255),
        'answer_area': (255, 0, 255)
    }
    for name, clr in colors.items():
        x, y, w, h = data[name]['position']
        cv2.rectangle(image, (x, y), (x + w, y + h), clr, 2)
        cv2.putText(image, name, (x, y - 5), FONT, 0.5, clr, 1)
    return image


def bounding_box(bubbles, shape):
    xs = [b['position'][0] for b in bubbles]
    ys = [b['position'][1] for b in bubbles]
    rs = [b['radius'] for b in bubbles]
    x1 = max(int(min(xs) - max(rs)), 0)
    x2 = min(int(max(xs) + max(rs)), shape[1])
    y1 = max(int(min(ys) - max(rs)), 0)
    y2 = min(int(max(ys) + max(rs)), shape[0])
    return x1, y1, x2, y2


def threshold_region(gray, box):
    x_min, y_min, x_max, y_max = box
    roi = gray[y_min:y_max, x_min:x_max]
    _, thresh = cv2.threshold(roi, 0, 255, cv2.THRESH_BINARY_INV | cv2.THRESH_OTSU)
    return thresh, (x_min, y_min)


def detect_marked(bubbles, thresh, min_pixels, origin):
    """
    Detect marked bubbles in thresholded image
    
    Args:
        bubbles: List of bubble definitions
        thresh: Thresholded image
        min_pixels: Minimum pixels to consider as marked
        origin: Origin offset (x_min, y_min) from bounding box
    
    Returns:
        marked: List of (pixel_count, bubble_index) tuples
    """
    marked = []
    x_min, y_min = origin
    for idx, b in enumerate(bubbles):
        x0 = int(b["position"][0] - x_min)
        y0 = int(b["position"][1] - y_min)
        r = int(b["radius"])
        mask = np.zeros_like(thresh)
        cv2.circle(mask, (x0, y0), r, 255, -1)
        cnt = cv2.countNonZero(cv2.bitwise_and(thresh, thresh, mask=mask))
        if cnt >= min_pixels:
            marked.append((cnt, idx))
    return marked


def draw_answer_circles(img, bubbles, selected, correct_idx):
    if len(selected) == 0:
        x, y = map(int, bubbles[correct_idx]['position'])
        r = int(bubbles[correct_idx]['radius'])
        cv2.circle(img, (x,y), r, COLORS['highlight'], 3)

    if len(selected) == 1:
        sel = selected[0]
        x, y = map(int, bubbles[sel]['position'])
        r = int(bubbles[sel]['radius'])
        if sel == correct_idx:
            cv2.circle(img, (x, y), r, COLORS['correct'], 3)
        else:
            cv2.circle(img, (x, y), r, COLORS['wrong'], 3)

            x2, y2 = map(int, bubbles[correct_idx]['position'])
            r2 = int(bubbles[correct_idx]['radius'])
            cv2.circle(img,(x2, y2), r2, COLORS['highlight'], 3)

    if correct_idx in selected:
        x, y = map(int, bubbles[correct_idx]['position'])
        r = int(bubbles[correct_idx]['radius'])
        cv2.circle(img, (x, y), r, COLORS['correct'], 3)
        for sel in selected:
            if sel == correct_idx: continue
            x, y = map(int, bubbles[sel]['position'])
            r = int(bubbles[sel]['radius'])
            cv2.circle(img, (x, y), r, COLORS['wrong'], 3)

    else:
        x2, y2 = map(int, bubbles[correct_idx]['position'])
        r2 = int(bubbles[correct_idx]['radius'])
        cv2.circle(img, (x2, y2), r2, COLORS['highlight'], 3)
        for sel in selected:
            x, y = map(int, bubbles[sel]['position'])
            r = int(bubbles[sel]['radius'])
            cv2.circle(img, (x, y), r, COLORS['wrong'], 3)


def grade_answers(img, gray, questions, answer_key):
    """
    Grade answers and draw circles on image
    
    Args:
        img: Image to draw on
        gray: Grayscale image
        questions: List of question definitions from template
        answer_key: Dict {question_index: answer_index}
    
    Returns:
        correct: Number of correct answers
    """
    correct = 0
    for q in questions:
        q_idx = q['question'] - 1
        bubbles = q['bubbles']
        box = bounding_box(bubbles, img.shape)
        thresh, origin = threshold_region(gray, box)

        marked = []
        for cnt, idx in detect_marked(bubbles, thresh, MIN_ANSWER_PIXELS, origin):
            marked.append(idx)

        selected, status = [], 'skipped'
        if len(marked) == 1:
            selected = marked
        elif len(marked) > 1:
            selected = marked
            status = 'multiple'

        correct_idx = answer_key.get(q_idx)
        if correct_idx is not None:
            if status == 'skipped':
                status = 'correct' if not marked else 'wrong'
                if marked and marked[0] == correct_idx:
                    correct += 1
            elif status == 'correct' or (len(marked) == 1 and marked[0] == correct_idx):
                correct += 1

            draw_answer_circles(img, bubbles, selected, correct_idx)
    return correct


def grade_answers_with_details(img, gray, questions, answer_key_dict):
    """
    Grade answers and return detailed results
    
    Args:
        img: Image to draw on
        gray: Grayscale image
        questions: List of question definitions from template
        answer_key_dict: Dict {question_index: answer_index}
    
    Returns:
        tuple: (score: int, answers: dict)
        answers: {question_index: answer_index}
    """
    correct = 0
    answers = {}
    
    for q in questions:
        q_idx = q['question'] - 1
        bubbles = q['bubbles']
        box = bounding_box(bubbles, img.shape)
        thresh, origin = threshold_region(gray, box)
        
        marked = []
        for cnt, idx in detect_marked(bubbles, thresh, MIN_ANSWER_PIXELS, origin):
            marked.append(idx)
        
        # Determine selected answer
        selected = None
        if len(marked) == 1:
            selected = marked[0]
        elif len(marked) > 1:
            # Multiple answers marked - take first one
            selected = marked[0]
        
        # Store answer
        answers[q_idx] = selected if selected is not None else -1
        
        # Check if correct
        correct_idx = answer_key_dict.get(q_idx)
        if correct_idx is not None:
            if selected is not None and selected == correct_idx:
                correct += 1
            
            # Draw circles
            draw_answer_circles(img, bubbles, [selected] if selected is not None else [], correct_idx)
    
    return correct, answers


def read_answers_only(img, gray, questions):
    """
    Read answers without grading
    
    Args:
        img: Image (not used, but kept for consistency)
        gray: Grayscale image
        questions: List of question definitions from template
    
    Returns:
        dict: {question_index: answer_index}
    """
    answers = {}
    
    for q in questions:
        q_idx = q['question'] - 1
        bubbles = q['bubbles']
        box = bounding_box(bubbles, img.shape)
        thresh, origin = threshold_region(gray, box)
        
        marked = []
        for cnt, idx in detect_marked(bubbles, thresh, MIN_ANSWER_PIXELS, origin):
            marked.append(idx)
        
        # Determine selected answer
        selected = None
        if len(marked) == 1:
            selected = marked[0]
        elif len(marked) > 1:
            selected = marked[0]  # Take first one
        
        answers[q_idx] = selected if selected is not None else -1
    
    return answers


def read_id_section(img, gray, sec, label):
    digits = []
    for col in sec['columns']:
        box, origin = bounding_box(col['bubbles'], gray.shape), None
        thresh, origin = threshold_region(gray, box)
        best = None
        for b in col['bubbles']:
            x = int(b['position'][0] - origin[0])
            y = int(b['position'][1] - origin[1])
            r = int(b['radius'])
            mask = np.zeros_like(thresh, dtype=np.uint8)
            cv2.circle(mask, (x, y), r, 255, -1)
            cnt = cv2.countNonZero(cv2.bitwise_and(thresh, thresh, mask=mask))
            if cnt >= MIN_ID_PIXELS[label] and (best is None or cnt > best[0]):
                best = (cnt, b['value'], b)
        if best is None:
            return None
        _, val, bub = best
        digits.append(val)
        # highlight bubble chọn
        px, py, pr = map(int, bub['position'] + [bub['radius']])
        cv2.circle(img, (px, py), pr, COLORS['correct'], 2)
    return digits


def encode_image_base64(img):
    """
    Encode image to base64 string
    
    Args:
        img: Image as numpy array
    
    Returns:
        str: Base64 encoded image
    """
    # Encode image to JPEG
    _, buffer = cv2.imencode('.jpg', img)
    # Encode to base64
    image_base64 = base64.b64encode(buffer).decode('utf-8')
    return image_base64


def process_answer_sheet(
    image_path: str,
    template_json_path: str,
    answer_key_dict: Optional[Dict[int, int]] = None,
    save_warped: bool = False,
    output_dir: Optional[str] = None
) -> Dict:
    """
    Process answer sheet image and grade answers
    
    Args:
        image_path: Path to input image
        template_json_path: Path to template JSON
        answer_key_dict: Dict {question_index: answer_index} (optional)
        save_warped: Whether to save warped image
        output_dir: Directory to save output images (optional)
    
    Returns:
        dict: {
            'score': int,
            'total_questions': int,
            'percentage': float,
            'student_id': List[int],
            'quiz_id': List[int],
            'class_id': List[int],
            'answers': dict,  # {question_index: answer_index}
            'warped_image': np.ndarray,  # Optional
            'annotated_image': np.ndarray,
        }
    """
    # 1. Load image and template
    orig, gray, data = load_data(image_path, template_json_path)
    
    # 2. Detect ArUco markers
    det = detect_aruco(gray, ARUCO_TYPE)
    
    # Check if we have enough markers (need at least 4)
    if len(det) < 4:
        corner_ids = {1, 5, 9, 10}
        detected_ids = {m['id'] for m in det if m['id'] in corner_ids}
        missing_ids = corner_ids - detected_ids
        raise ValueError(
            f'ArUco markers not detected. Missing markers: {missing_ids}. '
            f'Detected: {detected_ids}. '
            f'Please ensure all 4 corner markers are visible and well-lit.'
        )
    
    # 3. Warp image to template
    warped = warp_to_template(orig, det, data['aruco_marker'])
    
    if warped is None:
        raise ValueError("Failed to warp image to template")
    
    # 4. Convert to grayscale
    w_gray = cv2.cvtColor(warped, cv2.COLOR_BGR2GRAY)
    
    # 5. Read IDs
    stu_id = read_id_section(warped, w_gray, data['student_id_section'], 'student')
    quiz_id = read_id_section(warped, w_gray, data['quiz_id_section'], 'quiz')
    cls_id = read_id_section(warped, w_gray, data['class_id_section'], 'class')
    
    # 6. Grade answers or read answers only
    total_questions = len(data['answer_area']['questions'])
    score = 0
    answers = {}
    
    if answer_key_dict:
        # Grade with answer key
        score, answers = grade_answers_with_details(
            warped, w_gray, data['answer_area']['questions'], answer_key_dict
        )
    else:
        # Just read answers without grading
        answers = read_answers_only(warped, w_gray, data['answer_area']['questions'])
    
    # 7. Calculate percentage
    percentage = (score / total_questions * 100) if answer_key_dict else 0.0
    
    # 8. Add text overlay to annotated image
    annotated_img = warped.copy()
    lines = [f"Score: {score}/{total_questions} = {percentage:.2f}%"]
    if stu_id:
        lines.append("Student ID: " + ''.join(map(str, stu_id)))
    if quiz_id:
        lines.append("Quiz ID:    " + ''.join(map(str, quiz_id)))
    if cls_id:
        lines.append("Class ID:   " + ''.join(map(str, cls_id)))
    for i, txt in enumerate(lines):
        cv2.putText(annotated_img, txt, (10, 30 + i * 30), FONT, 0.8, COLORS['text'], 2)
    
    # 9. Save warped image if requested
    warped_path = None
    if save_warped and output_dir:
        import os
        os.makedirs(output_dir, exist_ok=True)
        base_name = os.path.splitext(os.path.basename(image_path))[0]
        warped_path = os.path.join(output_dir, f"warped_{base_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg")
        cv2.imwrite(warped_path, warped)
    
    # 10. Return result
    result = {
        'score': score,
        'total_questions': total_questions,
        'percentage': percentage,
        'student_id': stu_id if stu_id else [],
        'quiz_id': quiz_id if quiz_id else [],
        'class_id': cls_id if cls_id else [],
        'answers': answers,
        'annotated_image': annotated_img,
        'timestamp': datetime.now().isoformat(),
    }
    
    if warped_path:
        result['warped_image_path'] = warped_path
    
    return result


# Keep old main() for backward compatibility (standalone testing)
def main():
    """
    Standalone function for testing (deprecated - use process_answer_sheet instead)
    """
    import warnings
    warnings.warn(
        "main() is deprecated. Use process_answer_sheet() instead.",
        DeprecationWarning
    )
    # This function is kept for backward compatibility but should not be used in production
    pass