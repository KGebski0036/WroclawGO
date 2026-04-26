from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer
from .models import Attraction, Achievement, AvatarItem, Category, User, UserAchievement, UserAvatarItem, UserEquippedAvatarItem, VisitedAttraction

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name']

class UserSerializer(serializers.ModelSerializer):
    profile_picture = serializers.SerializerMethodField()
    equipped_items = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'points', 'profile_picture', 'equipped_items']

    def get_profile_picture(self, obj):
        request = self.context.get('request')
        if obj.profile_picture and request is not None:
            return request.build_absolute_uri(obj.profile_picture.url)
        if obj.profile_picture:
            return obj.profile_picture.url
        return None

    def get_equipped_items(self, obj):
        equipped = UserEquippedAvatarItem.objects.filter(user=obj).select_related('item').order_by('slot')
        return UserEquippedAvatarItemSerializer(equipped, many=True).data


class UserRankingSerializer(serializers.ModelSerializer):
    level = serializers.SerializerMethodField()
    equipped_items = serializers.SerializerMethodField()
    rank = serializers.IntegerField(read_only=True)
    is_liked = serializers.BooleanField(read_only=True)
    favorites_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'points', 'level', 'rank', 'is_liked', 'favorites_count', 'equipped_items']

    def get_level(self, obj):
        return (obj.points // 100) + 1

    def get_equipped_items(self, obj):
        equipped = getattr(obj, 'equipped_avatar_items', None)
        if equipped is not None and hasattr(equipped, 'all'):
            items = equipped.all()
            return UserEquippedAvatarItemSerializer(items, many=True).data
        equipped_fallback = UserEquippedAvatarItem.objects.filter(user=obj).select_related('item').order_by('slot')
        return UserEquippedAvatarItemSerializer(equipped_fallback, many=True).data


class UserPublicProfileSerializer(serializers.ModelSerializer):
    level = serializers.SerializerMethodField()
    equipped_items = serializers.SerializerMethodField()
    achievements = serializers.SerializerMethodField()
    rank = serializers.IntegerField(read_only=True)
    is_liked = serializers.BooleanField(read_only=True)
    favorites_count = serializers.IntegerField(read_only=True)
    achievements_total = serializers.IntegerField(read_only=True)
    visited_total = serializers.IntegerField(read_only=True)

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'points',
            'level',
            'rank',
            'is_liked',
            'favorites_count',
            'achievements_total',
            'visited_total',
            'equipped_items',
            'achievements',
        ]

    def get_level(self, obj):
        return (obj.points // 100) + 1

    def get_equipped_items(self, obj):
        equipped = getattr(obj, 'equipped_avatar_items', None)
        if equipped is not None and hasattr(equipped, 'all'):
            items = equipped.all()
            return UserEquippedAvatarItemSerializer(items, many=True).data
        equipped_fallback = UserEquippedAvatarItem.objects.filter(user=obj).select_related('item').order_by('slot')
        return UserEquippedAvatarItemSerializer(equipped_fallback, many=True).data

    def get_achievements(self, obj):
        earned = getattr(obj, 'achievements', None)
        if earned is not None and hasattr(earned, 'all'):
            return UserAchievementSerializer(earned.all().order_by('-earned_at'), many=True).data
        earned_fallback = UserAchievement.objects.filter(user=obj).select_related('achievement').order_by('-earned_at')
        return UserAchievementSerializer(earned_fallback, many=True).data


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


class AvatarItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = AvatarItem
        fields = ['id', 'tag', 'name', 'svg_path', 'cost', 'is_default']


class UserAvatarItemSerializer(serializers.ModelSerializer):
    item = AvatarItemSerializer(read_only=True)

    class Meta:
        model = UserAvatarItem
        fields = ['id', 'item', 'unlocked_at']


class UserEquippedAvatarItemSerializer(serializers.ModelSerializer):
    item = AvatarItemSerializer(read_only=True)

    class Meta:
        model = UserEquippedAvatarItem
        fields = ['id', 'slot', 'item', 'updated_at']


class VisitedAttractionSerializer(serializers.ModelSerializer):
    attraction = AttractionSerializer(read_only=True)

    class Meta:
        model = VisitedAttraction
        fields = ['id', 'attraction', 'visited_at']


class AchievementSerializer(serializers.ModelSerializer):
    class Meta:
        model = Achievement
        fields = ['id', 'name', 'description', 'badge_path', 'points_reward']


class UserAchievementSerializer(serializers.ModelSerializer):
    achievement = AchievementSerializer(read_only=True)

    class Meta:
        model = UserAchievement
        fields = ['id', 'achievement', 'earned_at']