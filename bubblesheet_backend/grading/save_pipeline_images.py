"""
Script để lưu các ảnh trung gian trong quy trình chấm bài
Dùng để tạo hình minh họa cho đồ án
"""
import cv2
import numpy as np
import json
import os
from datetime import datetime
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
    enhanced = clahe.apply(blurred)
    arucoDict = cv2.aruco.getPredefinedDictionary(ARUCO_DICT[aruco_type])
    arucoParams = cv2.aruco.DetectorParameters()
    arucoDetector = cv2.aruco.ArucoDetector(arucoDict, arucoParams)
    (corners, ids, _) = arucoDetector.detectMarkers(enhanced)
    positions = []
    if ids is not None:
        ids = ids.flatten()
        for markerCorner, markerID in zip(corners, ids):
            corners_reshaped = markerCorner.reshape((4, 2))
            (topLeft, topRight, bottomRight, bottomLeft) = corners_reshaped
            cX = int((topLeft[0] + bottomRight[0]) / 2.0)
            cY = int((topLeft[1] + bottomRight[1]) / 2.0)
            positions.append({'id': int(markerID), 'position': [cX, cY], 'corners': corners_reshaped})
    return positions, blurred, enhanced


def warp_to_template(img, detected, template_markers, output_size=(2481, 3508)):
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


def draw_aruco_markers_on_image(img, detected_markers):
    """Vẽ ArUco markers lên ảnh để minh họa"""
    img_copy = img.copy()
    for marker in detected_markers:
        marker_id = marker['id']
        corners = marker.get('corners', None)
        if corners is not None:
            # Vẽ 4 góc của marker
            corners_int = corners.astype(np.int32)
            cv2.polylines(img_copy, [corners_int], True, (0, 255, 0), 2)
            # Vẽ tâm
            center = marker['position']
            cv2.circle(img_copy, (int(center[0]), int(center[1])), 5, (0, 0, 255), -1)
            # Vẽ ID
            cv2.putText(img_copy, str(marker_id), 
                       (int(center[0]) - 10, int(center[1]) - 10), 
                       FONT, 0.7, (255, 0, 0), 2)
    return img_copy


def save_threshold_example(gray, template_data, output_dir):
    """Lưu ví dụ về thresholding cho một vùng ID section"""
    # Lấy một cột từ student_id_section làm ví dụ
    student_section = template_data.get('student_id_section', {})
    columns = student_section.get('columns', [])
    
    if not columns:
        return None
    
    # Lấy cột đầu tiên
    first_column = columns[0]
    bubbles = first_column.get('bubbles', [])
    
    if not bubbles:
        return None
    
    # Tìm bounding box
    xs = [b['position'][0] for b in bubbles]
    ys = [b['position'][1] for b in bubbles]
    rs = [b['radius'] for b in bubbles]
    x1 = max(int(min(xs) - max(rs)), 0)
    x2 = min(int(max(xs) + max(rs)), gray.shape[1])
    y1 = max(int(min(ys) - max(rs)), 0)
    y2 = min(int(max(ys) + max(rs)), gray.shape[0])
    
    # Trích xuất ROI
    roi = gray[y1:y2, x1:x2]
    
    # Threshold
    _, thresh = cv2.threshold(roi, 0, 255, cv2.THRESH_BINARY_INV | cv2.THRESH_OTSU)
    
    # Vẽ bubbles lên ảnh gốc
    roi_colored = cv2.cvtColor(roi, cv2.COLOR_GRAY2BGR)
    for b in bubbles:
        x = int(b['position'][0] - x1)
        y = int(b['position'][1] - y1)
        r = int(b['radius'])
        # Đếm pixel đen
        mask = np.zeros_like(thresh)
        cv2.circle(mask, (x, y), r, 255, -1)
        cnt = cv2.countNonZero(cv2.bitwise_and(thresh, thresh, mask=mask))
        
        # Vẽ vòng tròn với màu khác nhau
        if cnt >= MIN_ID_PIXELS['student']:
            cv2.circle(roi_colored, (x, y), r, (0, 255, 0), 2)  # Xanh = được chọn
        else:
            cv2.circle(roi_colored, (x, y), r, (0, 0, 255), 1)  # Đỏ = không được chọn
    
    # Ghép 3 ảnh: gốc, threshold, và kết quả
    thresh_colored = cv2.cvtColor(thresh, cv2.COLOR_GRAY2BGR)
    combined = np.hstack([roi_colored, thresh_colored])
    
    output_path = os.path.join(output_dir, 'step_thresholding_example.jpg')
    cv2.imwrite(output_path, combined)
    return output_path


def save_bubble_detection_example(gray, template_data, output_dir):
    """Lưu ví dụ về phát hiện bubble cho một câu hỏi"""
    answer_area = template_data.get('answer_area', {})
    questions = answer_area.get('questions', [])
    
    if not questions:
        return None
    
    # Lấy câu hỏi đầu tiên
    first_question = questions[0]
    bubbles = first_question.get('bubbles', [])
    
    if not bubbles:
        return None
    
    # Tìm bounding box
    xs = [b['position'][0] for b in bubbles]
    ys = [b['position'][1] for b in bubbles]
    rs = [b['radius'] for b in bubbles]
    x1 = max(int(min(xs) - max(rs)), 0)
    x2 = min(int(max(xs) + max(rs)), gray.shape[1])
    y1 = max(int(min(ys) - max(rs)), 0)
    y2 = min(int(max(ys) + max(rs)), gray.shape[0])
    
    # Trích xuất ROI
    roi = gray[y1:y2, x1:x2]
    
    # Threshold
    _, thresh = cv2.threshold(roi, 0, 255, cv2.THRESH_BINARY_INV | cv2.THRESH_OTSU)
    
    # Vẽ bubbles lên ảnh
    roi_colored = cv2.cvtColor(roi, cv2.COLOR_GRAY2BGR)
    marked_bubbles = []
    
    for idx, b in enumerate(bubbles):
        x = int(b['position'][0] - x1)
        y = int(b['position'][1] - y1)
        r = int(b['radius'])
        # Đếm pixel đen
        mask = np.zeros_like(thresh)
        cv2.circle(mask, (x, y), r, 255, -1)
        cnt = cv2.countNonZero(cv2.bitwise_and(thresh, thresh, mask=mask))
        
        # Vẽ vòng tròn với màu khác nhau
        if cnt >= MIN_ANSWER_PIXELS:
            cv2.circle(roi_colored, (x, y), r, (0, 255, 0), 3)  # Xanh = được tô
            marked_bubbles.append((idx, cnt))
        else:
            cv2.circle(roi_colored, (x, y), r, (128, 128, 128), 1)  # Xám = không được tô
    
    # Ghép ảnh
    thresh_colored = cv2.cvtColor(thresh, cv2.COLOR_GRAY2BGR)
    combined = np.hstack([roi_colored, thresh_colored])
    
    output_path = os.path.join(output_dir, 'step_bubble_detection_example.jpg')
    cv2.imwrite(output_path, combined)
    return output_path


def save_pipeline_images(image_path, template_json_path, output_dir='pipeline_images'):
    """
    Lưu tất cả các ảnh trung gian trong pipeline
    
    Args:
        image_path: Đường dẫn đến ảnh đầu vào
        template_json_path: Đường dẫn đến file JSON template
        output_dir: Thư mục để lưu các ảnh
    
    Returns:
        dict: Dictionary chứa đường dẫn đến các ảnh đã lưu
    """
    # Tạo thư mục output
    os.makedirs(output_dir, exist_ok=True)
    
    # Timestamp để tránh trùng tên
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    base_name = os.path.splitext(os.path.basename(image_path))[0]
    
    saved_images = {}
    
    # 1. Load ảnh gốc
    orig, gray, data = load_data(image_path, template_json_path)
    saved_images['1_original'] = os.path.join(output_dir, f'{base_name}_1_original.jpg')
    cv2.imwrite(saved_images['1_original'], orig)
    
    # 2. Ảnh grayscale
    saved_images['2_grayscale'] = os.path.join(output_dir, f'{base_name}_2_grayscale.jpg')
    cv2.imwrite(saved_images['2_grayscale'], gray)
    
    # 3. Preprocessing: Gaussian Blur
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    saved_images['3_gaussian_blur'] = os.path.join(output_dir, f'{base_name}_3_gaussian_blur.jpg')
    cv2.imwrite(saved_images['3_gaussian_blur'], blurred)
    
    # 4. Preprocessing: CLAHE
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(blurred)
    saved_images['4_clahe'] = os.path.join(output_dir, f'{base_name}_4_clahe.jpg')
    cv2.imwrite(saved_images['4_clahe'], enhanced)
    
    # 5. Phát hiện ArUco markers và vẽ lên ảnh
    detected_markers, _, _ = detect_aruco(gray, ARUCO_TYPE)
    img_with_markers = draw_aruco_markers_on_image(orig, detected_markers)
    saved_images['5_aruco_detected'] = os.path.join(output_dir, f'{base_name}_5_aruco_detected.jpg')
    cv2.imwrite(saved_images['5_aruco_detected'], img_with_markers)
    
    # 6. Ảnh đã warp
    warped = warp_to_template(orig, detected_markers, data['aruco_marker'])
    saved_images['6_warped'] = os.path.join(output_dir, f'{base_name}_6_warped.jpg')
    cv2.imwrite(saved_images['6_warped'], warped)
    
    # 7. Ảnh warped grayscale
    w_gray = cv2.cvtColor(warped, cv2.COLOR_BGR2GRAY)
    saved_images['7_warped_grayscale'] = os.path.join(output_dir, f'{base_name}_7_warped_grayscale.jpg')
    cv2.imwrite(saved_images['7_warped_grayscale'], w_gray)
    
    # 8. Ví dụ thresholding cho ID section
    threshold_example = save_threshold_example(w_gray, data, output_dir)
    if threshold_example:
        saved_images['8_threshold_example'] = threshold_example
    
    # 9. Ví dụ bubble detection cho câu hỏi
    bubble_example = save_bubble_detection_example(w_gray, data, output_dir)
    if bubble_example:
        saved_images['9_bubble_detection_example'] = bubble_example
    
    print(f"Đã lưu {len(saved_images)} ảnh vào thư mục: {output_dir}")
    for key, path in saved_images.items():
        print(f"  {key}: {path}")
    
    return saved_images


if __name__ == "__main__":
    # Ví dụ sử dụng
    import sys
    
    if len(sys.argv) < 3:
        print("Usage: python save_pipeline_images.py <image_path> <template_json_path> [output_dir]")
        sys.exit(1)
    
    image_path = sys.argv[1]
    template_json_path = sys.argv[2]
    output_dir = sys.argv[3] if len(sys.argv) > 3 else 'pipeline_images'
    
    saved_images = save_pipeline_images(image_path, template_json_path, output_dir)
    print("\nCác ảnh đã được lưu:")
    for key, path in saved_images.items():
        print(f"  {key}: {os.path.abspath(path)}")
