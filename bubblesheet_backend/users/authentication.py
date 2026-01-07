from rest_framework_simplejwt.authentication import JWTAuthentication
from bson import ObjectId

class MongoEngineJWTAuthentication(JWTAuthentication):
    def get_user(self, validated_token):
        user_id = validated_token.get('user_id')
        if user_id is None:
            return None

        try:
            # Convert string to ObjectId
            user_id = ObjectId(user_id)
            from users.models import User
            return User.objects.get(id=user_id)
        except (User.DoesNotExist, ValueError):
            return None 