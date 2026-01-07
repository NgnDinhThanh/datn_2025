from django.urls import path, include
from rest_framework.routers import DefaultRouter
from answer_sheets.views import AnswerSheetTemplateViewSet

router = DefaultRouter()
router.register(r'', AnswerSheetTemplateViewSet, basename='answer-sheet')

urlpatterns = router.urls