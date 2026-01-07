from rest_framework import serializers
from mongoengine.fields import ObjectIdField
from django.contrib.auth.hashers import make_password
from bson import ObjectId

from users.models import User


class UserSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    username = serializers.CharField(required=False)
    email = serializers.EmailField(required=False)
    password = serializers.CharField(write_only=True, required=False)
    is_teacher = serializers.BooleanField(default=True, required=False)


    def to_representation(self, instance):
        data = super().to_representation(instance)
        # Convert MongoDB _id to string
        data['id'] = str(instance.id)
        return data

    def to_internal_value(self, data):
        if 'id' in data:
            try:
                data['id'] = ObjectId(data['id'])
            except:
                pass
        return super().to_internal_value(data)
