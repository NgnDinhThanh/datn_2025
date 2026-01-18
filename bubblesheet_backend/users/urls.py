from django.urls import path
from users.views import UserListCreateView, UserDetailView, UserLoginView, CurrentUserProfileView, test_view

urlpatterns = [
    path('login/', UserLoginView.as_view(), name='user-login'),
    path('test/', test_view, name='test-view'),
    path('me/', CurrentUserProfileView.as_view(), name='current-user-profile'),
    path('', UserListCreateView.as_view(), name='user-list-create'),
    path('<str:id>/', UserDetailView.as_view(), name='user-detail'),
]