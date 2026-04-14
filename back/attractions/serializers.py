from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer
from .models import Attraction, Category, SkinColor, User, VisitedAttraction

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name']

class SkinColorSerializer(serializers.ModelSerializer):
    class Meta:
        model = SkinColor
        fields = ['id', 'name', 'color_value', 'price', 'image_file_name', 'is_premium']

class UserSerializer(serializers.ModelSerializer):
    profile_picture = serializers.SerializerMethodField()
    owned_skins = SkinColorSerializer(many=True, read_only=True)
    selected_skin = SkinColorSerializer(read_only=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'points', 'profile_picture', 'owned_skins', 'selected_skin']

    def get_profile_picture(self, obj):
        request = self.context.get('request')
        if obj.profile_picture and request is not None:
            return request.build_absolute_uri(obj.profile_picture.url)
        if obj.profile_picture:
            return obj.profile_picture.url
        return None


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password_confirm']
        extra_kwargs = {
            'username': {'validators': []},
            'email': {'validators': []},
        }

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return value

    def validate_username(self, value):
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError('This username is already in use.')
        return value

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({'password_confirm': ['Passwords do not match.']})

        user = User(username=attrs.get('username', ''), email=attrs.get('email', ''))

        try:
            validate_password(attrs['password'], user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({'password': list(exc.messages)})

        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        user = User.objects.create_user(password=password, **validated_data)
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        email = attrs['email'].strip()
        password = attrs['password']
        user = User.objects.filter(email__iexact=email).first()

        if user is None or not user.check_password(password):
            raise serializers.ValidationError({'non_field_errors': ['Invalid email or password.']})

        if not user.is_active:
            raise serializers.ValidationError({'non_field_errors': ['This account has been disabled.']})

        attrs['user'] = user
        return attrs

class AttractionSerializer(GeoFeatureModelSerializer):
    category = serializers.SlugRelatedField(
        read_only=True,
        slug_field='name'
    )

    class Meta:
        model = Attraction
        geo_field = "location"
        fields = ("id", "name", "description", "category", "points_reward")

class VisitedAttractionSerializer(serializers.ModelSerializer):
    attraction = AttractionSerializer(read_only=True)

    class Meta:
        model = VisitedAttraction
        fields = ['id', 'attraction', 'visited_at']