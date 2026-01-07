import os
import json
import logging
from datetime import datetime
from django.conf import settings
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
import fitz  # PyMuPDF
from rest_framework.response import Response
from rest_framework import status
from reportlab.lib import colors

logger = logging.getLogger(__name__)

# ----------------------- CÀI ĐẶT -----------------------
PAGE_WIDTH, PAGE_HEIGHT = A4  # Kích thước trang A4
dpi = 300
scale_factor = dpi / 72.0
IMAGE_HEIGHT = PAGE_HEIGHT * scale_factor

ARUCO_SIZE = 25
MARGIN = 40      # Khoảng cách từ mép giấy đến ArUCo markers

# Định nghĩa các offset cho marker
MARKER_OFFSET_TOP = 20      # Dịch chuyển theo hướng trên
MARKER_OFFSET_SIDE = 20     # Dịch chuyển theo hướng bên (trái/phải)
MARKER_OFFSET_BOTTOM = 18   # Dịch chuyển theo hướng dưới
MARKER_OFFSET_EXTRA = 20    # Offset thêm cho một số marker

# Xác định vùng an toàn (safe zone)
SAFE_MARGIN = MARGIN * 0.75 + ARUCO_SIZE
SAFE_ZONE = {
    "xmin": SAFE_MARGIN,
    "xmax": PAGE_WIDTH - SAFE_MARGIN,
    "ymin": SAFE_MARGIN,
    "ymax": PAGE_HEIGHT - SAFE_MARGIN
}

# Xác định các vùng bên trong safe zone
SAFE_WIDTH = SAFE_ZONE["xmax"] - SAFE_ZONE["xmin"]
SAFE_HEIGHT = SAFE_ZONE["ymax"] - SAFE_ZONE["ymin"]

INFO_HEIGHT = 220               # Chiều cao vùng thông tin
ANSWER_TOP_PADDING = 35
ANSWER_HEIGHT = SAFE_HEIGHT - INFO_HEIGHT - ANSWER_TOP_PADDING

# Định nghĩa các vùng
REGIONS = {
    "info_fill": (SAFE_ZONE["xmin"], SAFE_ZONE["ymax"] - INFO_HEIGHT, SAFE_WIDTH * 0.3, INFO_HEIGHT),
    "student_id": (SAFE_ZONE["xmin"] + SAFE_WIDTH * 0.3, SAFE_ZONE["ymax"] - INFO_HEIGHT, SAFE_WIDTH * 0.3, INFO_HEIGHT),
    "quiz_id": (SAFE_ZONE["xmin"] + SAFE_WIDTH * 0.6, SAFE_ZONE["ymax"] - INFO_HEIGHT, SAFE_WIDTH * 0.2, INFO_HEIGHT),
    "class_id": (SAFE_ZONE["xmin"] + SAFE_WIDTH * 0.8, SAFE_ZONE["ymax"] - INFO_HEIGHT, SAFE_WIDTH * 0.2, INFO_HEIGHT),
    "answer_area": (SAFE_ZONE["xmin"], SAFE_ZONE["ymin"], SAFE_WIDTH, ANSWER_HEIGHT)
}

def get_marker_positions(regions):
    """Calculate positions for all ArUCo markers"""
    info_fill = regions["info_fill"]
    student_id = regions["student_id"]
    quiz_id = regions["quiz_id"]
    class_id = regions["class_id"]
    answer_area = regions["answer_area"]

    # Marker positions
    marker_positions = {
        1: (info_fill[0] - MARKER_OFFSET_SIDE, info_fill[1] + info_fill[3] + MARKER_OFFSET_TOP),
        2: (info_fill[0] + info_fill[2], info_fill[1] + info_fill[3] + MARKER_OFFSET_TOP),
        3: (student_id[0] + student_id[2], student_id[1] + student_id[3] + MARKER_OFFSET_TOP),
        4: (quiz_id[0] + quiz_id[2], quiz_id[1] + quiz_id[3] + MARKER_OFFSET_TOP),
        5: (class_id[0] + class_id[2] + MARKER_OFFSET_EXTRA, class_id[1] + class_id[3] + MARKER_OFFSET_EXTRA),
        6: (student_id[0], student_id[1] - MARKER_OFFSET_BOTTOM),
        7: (quiz_id[0], quiz_id[1] - MARKER_OFFSET_BOTTOM),
        8: (class_id[0], class_id[1] - MARKER_OFFSET_BOTTOM),
        9: (answer_area[0] + answer_area[2] + MARKER_OFFSET_EXTRA, answer_area[1] - MARKER_OFFSET_EXTRA),
        10: (answer_area[0] - MARKER_OFFSET_EXTRA, answer_area[1] - MARKER_OFFSET_EXTRA),
        11: (answer_area[0] + answer_area[2]/2, answer_area[1] - MARKER_OFFSET_EXTRA),
        12: (answer_area[0] - MARKER_OFFSET_SIDE, answer_area[1] + answer_area[3] - ANSWER_HEIGHT * 0.01 + MARKER_OFFSET_SIDE),
        13: (answer_area[0] + answer_area[2] + MARKER_OFFSET_SIDE, answer_area[1] + answer_area[3] - ANSWER_HEIGHT * 0.01 + MARKER_OFFSET_SIDE)
    }
    return marker_positions

def draw_aruco_markers(c, positions, aruco_dir):
    """Draw ArUCo markers on the canvas"""
    aruco_data = []
    for marker_id, (x, y) in positions.items():
        size = ARUCO_SIZE
        if marker_id in {1, 5, 9, 10}:
            size = 35

        aruco_path = os.path.join(aruco_dir, f'aruco_{marker_id}.png')
        if os.path.exists(aruco_path):
            c.drawInlineImage(
                aruco_path,
                x - size / 2,
                y - size / 2,
                size,
                size
            )
        aruco_data.append({
            "id": marker_id,
            "position": [x, y],
            "size": size
        })
    return aruco_data

def draw_info_fill(c, region, labels, widths=None):
    x, y, width, height = region
    start_y = y + height - 30
    line_height = 25
    fields = []
    if widths is None:
        widths = ["Medium"] * len(labels)
    for i, label in enumerate(labels):
        label_x = x + 5
        label_y = start_y - 5
        # Xử lý cỡ chữ theo width
        size = 12
        if widths[i] == "Large":
            size = 16
        elif widths[i] == "Small":
            size = 10
        c.setFont("Helvetica", size)
        c.drawString(label_x, label_y, label)
        line_x_start = x + 40
        line_x_end = x + width - 10
        line_y = start_y - 4
        c.line(line_x_start, line_y, line_x_end, line_y)
        fields.append({
            "text": label,
            "label_pos": [label_x, label_y],
            "line": {
                "start": [line_x_start, line_y],
                "end": [line_x_end, line_y]
            }
        })
        start_y -= line_height
    return {
        "position": [x, y, width, height],
        "fields": fields
    }

def draw_id_section(c, region, label, num_digits):
    """Draw ID section with digit boxes and bubbles"""
    x, y, width, height = region
    box_size = 16
    bubble_radius = 6.5
    bubble_spacing_horizontal = 18
    bubble_spacing_vertical = 17
    label_margin = 15

    start_x = x + (width - num_digits * box_size) / 2
    c.setFont("Helvetica", 10)
    c.drawString(start_x, y + height - label_margin, label)

    # Draw digit boxes
    for i in range(num_digits):
        c.rect(start_x + i * box_size, y + height - box_size - 20, box_size, box_size)

    columns = []
    for col in range(num_digits):
        bubbles = []
        for num in range(10):
            bubble_x = start_x + col * box_size + box_size / 2
            bubble_y = y + height - box_size - 30 - num * bubble_spacing_vertical
            c.circle(bubble_x, bubble_y, bubble_radius)
            c.setFont("Helvetica-Bold", 7)
            c.drawCentredString(bubble_x, bubble_y - 2, str(num))
            bubbles.append({
                "value": num,
                "position": [bubble_x, bubble_y],
                "radius": bubble_radius
            })
        columns.append({
            "digits_index": col,
            "bubbles": bubbles
        })
    
    return {
        "position": [x, y, width, height],
        "digits": num_digits,
        "columns": columns
    }

def draw_answer_area(c, region, num_questions, num_options):
    """Draw answer area with question numbers and bubbles"""
    x, y, width, height = region
    bubble_radius = 6.5
    bubble_spacing_horizontal = 4
    bubble_spacing_vertical = 6
    options_list = "ABCDE"[:num_options]

    # Calculate number of columns
    if num_questions > 50:
        num_columns = 4
    elif num_questions > 20:
        num_columns = 2
    else:
        num_columns = 1

    questions_per_column = (num_questions + num_columns - 1) // num_columns
    row_height = 2 * bubble_radius + bubble_spacing_vertical
    total_height = questions_per_column * row_height
    number_spacing = 20
    column_width = num_options * (2 * bubble_radius + bubble_spacing_horizontal) - bubble_spacing_horizontal
    total_width = num_columns * column_width + number_spacing
    column_spacing = 35

    margin_x = 14
    start_x = x + margin_x + bubble_radius + (width - total_width - (num_columns - 1) * column_spacing) / 2
    margin_y = 14
    start_y = y + height - margin_y - (height - total_height - bubble_radius) / 2

    questions = []
    q_index = 1
    for col in range(num_columns):
        questions_in_this_column = (num_questions // num_columns) + (1 if col < num_questions % num_columns else 0)
        for row in range(questions_in_this_column):
            x_pos = start_x + col * (column_width + column_spacing)
            y_pos = start_y - row * row_height
            c.setFont("Helvetica", 9)
            c.drawRightString(x_pos - (number_spacing / 2), y_pos, f"{q_index}.")
            
            bubbles = []
            for i, option in enumerate(options_list):
                bubble_x = x_pos + i * (2 * bubble_radius + bubble_spacing_horizontal)
                c.circle(bubble_x, y_pos, bubble_radius)
                c.setFont("Helvetica-Bold", 7)
                c.drawCentredString(bubble_x, y_pos - 2, option)
                bubbles.append({
                    "option": option,
                    "position": [bubble_x, y_pos],
                    "radius": bubble_radius
                })
            
            questions.append({
                "question": q_index,
                "bubbles": bubbles
            })
            q_index += 1
    
    return {
        "position": [x, y, width, height],
        "num_questions": num_questions,
        "questions": questions
    }

def convert_point(point):
    """Convert PDF point to image coordinates"""
    x, y = point
    scale_x = x * scale_factor
    scale_y = y * scale_factor
    return [int(scale_x), int(IMAGE_HEIGHT - scale_y)]

def convert_box(box):
    """Convert PDF box to image coordinates"""
    x, y, w, h = box
    scale_x = x * scale_factor
    scale_y = y * scale_factor
    scale_w = w * scale_factor
    scale_h = h * scale_factor
    new_y = IMAGE_HEIGHT - (scale_y + scale_h)
    return [int(scale_x), int(new_y), int(scale_w), int(scale_h)]

def convert_bubble(bubble):
    """Convert bubble coordinates to image space"""
    new_bubble = bubble.copy()
    new_bubble["position"] = convert_point(bubble["position"])
    new_bubble["radius"] = int(bubble["radius"] * scale_factor)
    return new_bubble

def generate_answer_sheet(template, output_dir=None, aruco_dir=None, widths=None, file_id=None):
    """Generate answer sheet PDF and JSON metadata"""
    pdf_path = None
    json_path = None
    preview_path = None
    file_id = str(file_id) if file_id else str(template.id)

    try:
        # Use default directories from settings if not provided
        output_dir = output_dir or settings.ANSWER_SHEET_CONFIG['OUTPUT_DIR']
        aruco_dir = aruco_dir or settings.ANSWER_SHEET_CONFIG['ARUCO_MARKER_DIR']

        # Create output directory if not exists
        os.makedirs(output_dir, exist_ok=True)
        os.makedirs(settings.ANSWER_SHEET_CONFIG['PREVIEW_DIR'], exist_ok=True)

        # Generate PDF
        pdf_path = os.path.join(output_dir, f'{file_id}.pdf')
        c = canvas.Canvas(pdf_path, pagesize=A4)

        # Draw borders for ID regions
        highlight_regions = {"student_id", "quiz_id", "class_id"}
        border_color = (0.3, 0.3, 0.3)  # màu xám trung tính

        for region, (x, y, w, h) in REGIONS.items():
            if region in highlight_regions:
                c.setStrokeColorRGB(*border_color)
                c.rect(x, y, w, h)

        # Get marker positions and draw them
        marker_positions = get_marker_positions(REGIONS)
        aruco_markers = draw_aruco_markers(c, marker_positions, aruco_dir)

        # Lấy labels và widths động
        labels = getattr(template, 'labels', ["Name", "Quiz", "Class", "Score"])
        if widths is None:
            widths = getattr(template, 'widths', ["Medium"] * len(labels))
        info_data = draw_info_fill(c, REGIONS["info_fill"], labels, widths)
        student_id_data = draw_id_section(c, REGIONS["student_id"], "Student ID", template.student_id_digits)
        quiz_id_data = draw_id_section(c, REGIONS["quiz_id"], "Quiz ID", template.exam_id_digits)
        class_id_data = draw_id_section(c, REGIONS["class_id"], "Class ID", template.class_id_digits)
        answer_data = draw_answer_area(c, REGIONS["answer_area"], template.num_questions, template.num_options)

        c.save()

        # Generate preview image
        preview_path = os.path.join(
            settings.ANSWER_SHEET_CONFIG['PREVIEW_DIR'],
            f'{file_id}_preview.png'
        )
        doc = fitz.open(pdf_path)
        page = doc[0]
        pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
        pix.save(preview_path)
        doc.close()

        # Convert coordinates to image space
        output_data = {
            "aruco_marker": aruco_markers,
            "info_section": info_data,
            "student_id_section": student_id_data,
            "quiz_id_section": quiz_id_data,
            "class_id_section": class_id_data,
            "answer_area": answer_data
        }

        # Convert ArUCo markers
        for marker in output_data["aruco_marker"]:
            marker["position"] = convert_point(marker["position"])
            marker["size"] = int(marker["size"] * scale_factor)

        # Convert info section
        output_data["info_section"]["position"] = convert_box(output_data["info_section"]["position"])
        for field in output_data["info_section"]["fields"]:
            field["label_pos"] = convert_point(field["label_pos"])
            field["line"]["start"] = convert_point(field["line"]["start"])
            field["line"]["end"] = convert_point(field["line"]["end"])

        # Convert ID sections
        for key in ["student_id_section", "quiz_id_section", "class_id_section"]:
            section = output_data[key]
            section["position"] = convert_box(section["position"])
            for col in section["columns"]:
                new_bubbles = []
                for bubble in col["bubbles"]:
                    new_bubbles.append(convert_bubble(bubble))
                col["bubbles"] = new_bubbles

        # Convert answer area
        output_data["answer_area"]["position"] = convert_box(output_data["answer_area"]["position"])
        for question in output_data["answer_area"]["questions"]:
            new_bubbles = []
            for bubble in question["bubbles"]:
                new_bubbles.append(convert_bubble(bubble))
            question["bubbles"] = new_bubbles

        # Save JSON metadata
        json_path = os.path.join(output_dir, f'{file_id}.json')
        with open(json_path, 'w') as f:
            json.dump(output_data, f, indent=2)
        
        return pdf_path, json_path
        
    except Exception as e:
        logger.error(f"Error generating answer sheet: {str(e)}")
        # Clean up any created files
        for path in [pdf_path, json_path, preview_path]:
            if path and os.path.exists(path):
                try:
                    os.remove(path)
                except Exception as cleanup_error:
                    logger.error(f"Error cleaning up file {path}: {str(cleanup_error)}")
        raise

def cleanup_old_backups(output_dir=None, max_backups=None):
    """Clean up old backup files"""
    try:
        output_dir = output_dir or settings.ANSWER_SHEET_CONFIG['OUTPUT_DIR']
        max_backups = max_backups or settings.ANSWER_SHEET_CONFIG['MAX_BACKUPS']
        
        # Get all PDF files
        pdf_files = [f for f in os.listdir(output_dir) if f.endswith('.pdf')]
        
        # Sort by modification time
        pdf_files.sort(key=lambda x: os.path.getmtime(os.path.join(output_dir, x)))
        
        # Remove old files
        while len(pdf_files) > max_backups:
            old_file = pdf_files.pop(0)
            old_path = os.path.join(output_dir, old_file)
            
            # Remove PDF and corresponding JSON
            os.remove(old_path)
            json_path = old_path.replace('.pdf', '.json')
            if os.path.exists(json_path):
                os.remove(json_path)
            
            # Remove preview if exists
            preview_path = os.path.join(
                settings.ANSWER_SHEET_CONFIG['PREVIEW_DIR'],
                f'{os.path.splitext(old_file)[0]}_preview.png'
            )
            if os.path.exists(preview_path):
                os.remove(preview_path)
                
    except Exception as e:
        logger.error(f"Error cleaning up old backups: {str(e)}")
        raise

def validate_file_size(file_path, max_size_mb=None):
    """Validate file size"""
    try:
        max_size_mb = max_size_mb or settings.ANSWER_SHEET_CONFIG['MAX_FILE_SIZE_MB']
        size_mb = os.path.getsize(file_path) / (1024 * 1024)
        if size_mb > max_size_mb:
            raise ValueError(f"File size exceeds {max_size_mb}MB limit")
    except Exception as e:
        logger.error(f"Error validating file size: {str(e)}")
        raise

def validate_file_type(file_path, allowed_extensions=None):
    """Validate file type"""
    try:
        allowed_extensions = allowed_extensions or settings.ANSWER_SHEET_CONFIG['ALLOWED_EXTENSIONS']
        ext = os.path.splitext(file_path)[1].lower()
        if ext not in allowed_extensions:
            raise ValueError(f"File type {ext} not allowed")
    except Exception as e:
        logger.error(f"Error validating file type: {str(e)}")
        raise

def handle_file_operation_error(error, file_paths):
    """Handle file operation errors"""
    try:
        # Clean up files
        for path in file_paths:
            if os.path.exists(path):
                os.remove(path)
        
        # Log error
        logger.error(f"File operation error: {str(error)}")
        
        return Response(
            {'error': str(error)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
    except Exception as e:
        logger.error(f"Error handling file operation error: {str(e)}")
        raise

def get_file_info(file_path):
    """Get file information"""
    try:
        return {
            'path': file_path,
            'size': os.path.getsize(file_path),
            'modified': datetime.fromtimestamp(
                os.path.getmtime(file_path)
            ).isoformat()
        }
    except Exception as e:
        logger.error(f"Error getting file info: {str(e)}")
        raise 