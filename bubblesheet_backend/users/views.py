from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from bson import ObjectId
import logging
import traceback

logger = logging.getLogger(__name__)

from users.models import User
from users.serializers import UserSerializer

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
    permission_classes = [AllowAny]  # Allow unauthenticated access for registration

    def get(self, request):
        users = User.objects.all()
        serializer = UserSerializer(users, many=True)
        return Response(serializer.data)

    def post(self, request):
        try:
            logger.info(f"Received data: {request.data}")
            serializer = UserSerializer(data=request.data)
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
                'token': str(refresh.access_token)  # Only return access token
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
    permission_classes = [AllowAny]  # Remove authentication requirement

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
        logger.info(f"GET request for user {id}")
        user_obj = self.get_object(id)
        if not user_obj:
            return Response({'error': 'Not found'}, status=404)
        serializer = UserSerializer(user_obj)
        return Response(serializer.data)

    def put(self, request, id):
        user_obj = self.get_object(id)
        if not user_obj:
            return Response({'error': 'Not found'}, status=404)
        serializer = UserSerializer(user_obj, data=request.data)
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
        user_obj.delete()
        return Response(status=204)