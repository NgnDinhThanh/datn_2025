from django.urls import path

from grading.views import (
    GradeListView,
    GradeDetailView,
    scan_answer_sheet,
    preview_check_api,
    save_grade_api,
    get_grades_for_quiz,
    item_analysis,
    check_answer_key,
    grade_from_json_api,
    get_template_json_api,
)

urlpatterns = [
    # New grading URLs (MUST be before grades/<str:id>/ to avoid URL conflict)
    path('grades/by-quiz/', get_grades_for_quiz, name='get-grades-for-quiz'),
    
    # Existing URLs
    path('grades/', GradeListView.as_view(), name='grade-list-create'),
    path('grades/<str:id>/', GradeDetailView.as_view(), name='grade-detail'),
    
    # New scanning URLs
    path('scan/', scan_answer_sheet, name='scan-answer-sheet'),
    path('preview-check/', preview_check_api, name='preview-check'),
    path('save-grade/', save_grade_api, name='save-grade'),
    path('grade-from-json/', grade_from_json_api, name='grade-from-json'),
    path('template-json/', get_template_json_api, name='template-json'),
    
    # Other grading URLs
    path('item-analysis/', item_analysis, name='item-analysis'),
    path('check-answer-key/', check_answer_key, name='check-answer-key'),
]