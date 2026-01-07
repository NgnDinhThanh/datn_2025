from django.urls import path

from classes.views import ClassListCreateView, ClassDetailView, test_mongo

urlpatterns = [
    path('test/', test_mongo, name='test-mongo'),
    path('', ClassListCreateView.as_view(), name='class-list-create'),
    path('<str:class_code>/', ClassDetailView.as_view(), name='class-detail'),
]