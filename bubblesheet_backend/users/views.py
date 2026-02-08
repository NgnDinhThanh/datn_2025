from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from bson import ObjectId
import logging
import traceback

logger = logging.getLogger(__name__)

from users.models import User
from users.serializers import UserSerializer
from users.permissions import IsAdmin
from classes.models import Class
from students.models import Student
from exams.models import Exam
from grading.models import Grade

@api_view(['GET'])
@permission_classes([AllowAny])
def test_view(request):
    try:
        return Response({"message": "Test view working"})
    except Exception as e:
        return Response(
            {"error": str(e)}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

# Create your views here.

class UserListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == 'POST':
            return [AllowAny()]  # Register: public
        return [IsAdmin()]  # List users: admin only

    def get(self, request):
        users = User.objects.all()
        serializer = UserSerializer(users, many=True)
        return Response(serializer.data)

    def post(self, request):
        try:
            logger.info(f"Received data: {request.data}")
            data = dict(request.data)
            data.pop('is_admin', None)  # New users never get admin
            serializer = UserSerializer(data=data)
            if serializer.is_valid():
                logger.info(f"Validated data: {serializer.validated_data}")
                user_obj = User(**serializer.validated_data)
                user_obj.save()
                return Response(UserSerializer(user_obj).data, status=status.HTTP_201_CREATED)
            else:
                logger.error(f"Validation errors: {serializer.errors}")
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"Error creating user: {str(e)}")
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class UserLoginView(APIView):
    permission_classes = [AllowAny]  # Allow unauthenticated access for login
    
    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')

        if not email or not password:
            return Response(
                {'error': 'Please provide both email and password'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            user = User.objects.get(email=email)
            if user.password != password:
                return Response(
                    {'error': 'Invalid credentials'}, 
                    status=status.HTTP_401_UNAUTHORIZED
                )

            # Generate access token
            refresh = RefreshToken()
            refresh['user_id'] = str(user.id)
            refresh['email'] = user.email
            refresh['is_teacher'] = user.is_teacher

            return Response({
                'user': UserSerializer(user).data,
                'token': str(refresh.access_token),
                'is_admin': getattr(user, 'is_admin', False),
            })
        except User.DoesNotExist:
            return Response(
                {'error': 'Invalid credentials'}, 
                status=status.HTTP_401_UNAUTHORIZED
            )
        except Exception as e:
            return Response(
                {'error': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class UserDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        return [IsAuthenticated()]

    def _is_admin_or_owner(self, request, user_obj):
        return (
            getattr(request.user, 'is_admin', False) or
            str(request.user.id) == str(user_obj.id)
        )

    def get_object(self, id):
        try:
            logger.info(f"Looking for user with id: {id}")
            user = User.objects.get(id=id)
            logger.info(f"Found user: {user.email}")
            return user
        except User.DoesNotExist:
            logger.warning(f"User not found with id: {id}")
            return None
        except Exception as e:
            logger.error(f"Error getting user: {str(e)}")
            return None

    def get(self, request, id):
        user_obj = self.get_object(id)
        if not user_obj:
            return Response({'error': 'Not found'}, status=404)
        if not self._is_admin_or_owner(request, user_obj):
            return Response({'error': 'Forbidden'}, status=403)
        serializer = UserSerializer(user_obj)
        return Response(serializer.data)

    def put(self, request, id):
        user_obj = self.get_object(id)
        if not user_obj:
            return Response({'error': 'Not found'}, status=404)
        if not self._is_admin_or_owner(request, user_obj):
            return Response({'error': 'Forbidden'}, status=403)
        # Non-admin cannot change is_admin
        data = dict(request.data)
        if not getattr(request.user, 'is_admin', False):
            data.pop('is_admin', None)
        serializer = UserSerializer(user_obj, data=data, partial=True)
        if serializer.is_valid():
            for attr, value in serializer.validated_data.items():
                setattr(user_obj, attr, value)
            user_obj.save()
            return Response(UserSerializer(user_obj).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, id):
        user_obj = self.get_object(id)
        if not user_obj:
            return Response({'error': 'Not found'}, status=404)
        if not getattr(request.user, 'is_admin', False):
            return Response({'error': 'Only admin can delete users'}, status=403)
        user_obj.delete()
        return Response(status=204)


class CurrentUserProfileView(APIView):
    """
    Get current logged-in user's profile information and statistics.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            user = request.user
            
            # Get statistics for teacher
            stats = {
                'total_classes': 0,
                'total_students': 0,
                'total_quizzes': 0,
                'total_graded_papers': 0,
            }
            
            if user.is_teacher:
                # Count classes
                stats['total_classes'] = Class.objects(teacher_id=user.id).count()
                
                # Count students
                stats['total_students'] = Student.objects(teacher_id=user.id).count()
                
                # Count quizzes/exams
                stats['total_quizzes'] = Exam.objects(teacher_id=user.id).count()
                
                # Count graded papers
                stats['total_graded_papers'] = Grade.objects(teacher_id=user.id).count()
            
            # Build response
            response_data = {
                'id': str(user.id),
                'username': user.username,
                'email': user.email,
                'is_teacher': user.is_teacher,
                'is_admin': getattr(user, 'is_admin', False),
                'statistics': stats,
            }
            
            logger.info(f"Profile data retrieved for user {user.username}")
            return Response(response_data)

        except Exception as e:
            logger.error(f"Error in get current user profile: {str(e)}\n{traceback.format_exc()}")
            return Response(
                {"error": "Failed to retrieve user profile", "detail": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class AdminUsersListView(APIView):
    """List all users - admin only."""
    permission_classes = [IsAuthenticated, IsAdmin]

    def get(self, request):
        users = User.objects.all()
        serializer = UserSerializer(users, many=True)
        return Response(serializer.data)


class AdminStatsView(APIView):
    """System-wide statistics - admin only."""
    permission_classes = [IsAuthenticated, IsAdmin]

    def get(self, request):
        stats = {
            'total_users': User.objects.count(),
            'total_classes': Class.objects.count(),
            'total_students': Student.objects.count(),
            'total_quizzes': Exam.objects.count(),
            'total_graded_papers': Grade.objects.count(),
        }
        return Response(stats)