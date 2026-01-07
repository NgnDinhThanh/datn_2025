from django.urls import path
from .views import (
    GenerateAnswerKeyView,
    AnswerKeyListView,
    AnswerKeyDetailView, AnswerKeyDownloadAllExcelView
)

urlpatterns = [
    path('generate/', GenerateAnswerKeyView.as_view(), name='generate-answer-key'),
    path('quiz/<str:quiz_id>/', AnswerKeyListView.as_view(), name='answer-key-list'),
    path('<str:answer_key_id>/', AnswerKeyDetailView.as_view(), name='answer-key-detail'),
    path('quiz/<str:quiz_id>/download/', AnswerKeyDownloadAllExcelView.as_view()),
] 