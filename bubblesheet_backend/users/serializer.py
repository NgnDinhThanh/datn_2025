from rest_framework import serializers
from bson import ObjectId

class UserSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)
    is_teacher = serializers.BooleanField(default=False)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data['id'] = str(instance.id)  # Convert ObjectId to string
        return data

    def to_internal_value(self, data):
        if 'id' in data:
            try:
                data['id'] = ObjectId(data['id'])
            except:
                pass
        return super().to_internal_value(data) 