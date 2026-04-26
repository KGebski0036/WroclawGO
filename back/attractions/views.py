# attractions/views.py
import logging

from django.db.models import Count, Exists, F, OuterRef, Window
from django.db.models.functions import Rank
from rest_framework import generics, permissions, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from .models import Achievement, Attraction, AvatarItem, User, UserAchievement, UserAvatarItem, UserEquippedAvatarItem, UserFavorite, VisitedAttraction
from .serializers import (
    AchievementSerializer,
    AttractionSerializer,
    AvatarItemSerializer,
    LoginSerializer,
    RegisterSerializer,
    UserAchievementSerializer,
    UserAvatarItemSerializer,
    UserEquippedAvatarItemSerializer,
    UserPublicProfileSerializer,
    UserRankingSerializer,
    UserSerializer,
    VisitedAttractionSerializer,
)
from .achievement_service import check_achievements

logger = logging.getLogger(__name__)


class LoginAnonRateThrottle(AnonRateThrottle):
    scope = 'login_anon'


class LoginUserRateThrottle(UserRateThrottle):
    scope = 'login_user'


class CheckInRateThrottle(UserRateThrottle):
    scope = 'checkin'


class UserRankingPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class AttractionList(generics.ListAPIView):
    """
    Widok zwracający listę wszystkich atrakcji w formacie GeoJSON.
    """
    queryset = Attraction.objects.all()
    serializer_class = AttractionSerializer
    permission_classes = [permissions.AllowAny]


class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)

        return Response(
            {
                'user': UserSerializer(user, context={'request': request}).data,
                'access': str(refresh.access_token),
                'refresh': str(refresh),
            },
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [LoginAnonRateThrottle, LoginUserRateThrottle]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        refresh = RefreshToken.for_user(user)

        return Response(
            {
                'user': UserSerializer(user, context={'request': request}).data,
                'access': str(refresh.access_token),
                'refresh': str(refresh),
            }
        )


class LogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        refresh_token = request.data.get('refresh')

        if not refresh_token:
            return Response({'detail': 'Refresh token is required for logout.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
        except Exception:
            return Response({'detail': 'Invalid refresh token.'}, status=status.HTTP_400_BAD_REQUEST)

        return Response(status=status.HTTP_204_NO_CONTENT)


class CurrentUserView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user, context={'request': request}).data)


class AvatarItemListView(generics.ListAPIView):
    queryset = AvatarItem.objects.all().order_by('tag', 'cost')
    serializer_class = AvatarItemSerializer
    permission_classes = [permissions.IsAuthenticated]


class UserAvatarItemListView(generics.ListAPIView):
    serializer_class = UserAvatarItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return UserAvatarItem.objects.filter(user=self.request.user).select_related('item')


class PurchaseAvatarItemView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, item_id):
        try:
            item = AvatarItem.objects.get(pk=item_id)
        except AvatarItem.DoesNotExist:
            return Response({'detail': 'Item not found.'}, status=status.HTTP_404_NOT_FOUND)

        if UserAvatarItem.objects.filter(user=request.user, item=item).exists():
            return Response({'detail': 'Item already owned.'}, status=status.HTTP_400_BAD_REQUEST)

        if request.user.points < item.cost:
            return Response({'detail': 'Insufficient points.'}, status=status.HTTP_400_BAD_REQUEST)

        request.user.points -= item.cost
        request.user.save(update_fields=['points'])
        unlocked = UserAvatarItem.objects.create(user=request.user, item=item)

        return Response(UserAvatarItemSerializer(unlocked).data, status=status.HTTP_201_CREATED)


class UserEquippedAvatarItemListView(generics.ListAPIView):
    serializer_class = UserEquippedAvatarItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return UserEquippedAvatarItem.objects.filter(user=self.request.user).select_related('item').order_by('slot')


class EquipAvatarItemView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, item_id):
        try:
            item = AvatarItem.objects.get(pk=item_id)
        except AvatarItem.DoesNotExist:
            return Response({'detail': 'Item not found.'}, status=status.HTTP_404_NOT_FOUND)

        unlocked = UserAvatarItem.objects.filter(user=request.user, item=item).exists()
        if not unlocked:
            return Response({'detail': 'Item is not unlocked.'}, status=status.HTTP_400_BAD_REQUEST)

        equipped, _ = UserEquippedAvatarItem.objects.update_or_create(
            user=request.user,
            slot=item.tag,
            defaults={'item': item},
        )

        return Response(UserEquippedAvatarItemSerializer(equipped).data, status=status.HTTP_200_OK)


class VisitedAttractionListView(generics.ListAPIView):
    serializer_class = VisitedAttractionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return VisitedAttraction.objects.filter(user=self.request.user).select_related('attraction').order_by('-visited_at')


class MarkAttractionVisitedView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [CheckInRateThrottle]

    def post(self, request, attraction_id):
        try:
            attraction = Attraction.objects.get(pk=attraction_id)
        except Attraction.DoesNotExist:
            return Response({'detail': 'Attraction not found.'}, status=status.HTTP_404_NOT_FOUND)

        if VisitedAttraction.objects.filter(user=request.user, attraction=attraction).exists():
            return Response({'detail': 'Attraction already marked as visited.'}, status=status.HTTP_400_BAD_REQUEST)

        visited = VisitedAttraction.objects.create(user=request.user, attraction=attraction)
        # Points are awarded via the post_save signal on VisitedAttraction.
        newly_earned = check_achievements(request.user)

        client_platform = request.headers.get('X-Client-Platform', 'unknown')
        app_version = request.headers.get('X-App-Version', 'unknown')
        user_agent = request.META.get('HTTP_USER_AGENT', 'unknown')
        logger.info(
            'Visit check-in created user_id=%s attraction_id=%s platform=%s app_version=%s user_agent=%s',
            request.user.id,
            attraction.id,
            client_platform,
            app_version,
            user_agent,
        )

        return Response(
            {
                'visited': VisitedAttractionSerializer(visited).data,
                'newly_earned': AchievementSerializer(newly_earned, many=True).data,
                'awarded_points': attraction.points_reward,
                'current_points': request.user.points,
            },
            status=status.HTTP_201_CREATED,
        )


class UnmarkAttractionVisitedView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, attraction_id):
        return Response(
            {
                'detail': 'Removing visited attractions is disabled to protect points integrity.'
            },
            status=status.HTTP_403_FORBIDDEN,
        )


class AchievementListView(generics.ListAPIView):
    queryset = Achievement.objects.all().order_by('id')
    serializer_class = AchievementSerializer
    permission_classes = [permissions.IsAuthenticated]


class UserAchievementListView(generics.ListAPIView):
    serializer_class = UserAchievementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return UserAchievement.objects.filter(user=self.request.user).select_related('achievement').order_by('-earned_at')


class UserRankingListView(generics.ListAPIView):
    serializer_class = UserRankingSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = UserRankingPagination

    def get_queryset(self):
        current_user = self.request.user
        search = self.request.query_params.get('search', '').strip()
        liked_only = self.request.query_params.get('liked_only', '').strip().lower() in {'1', 'true', 'yes', 'on'}
        queryset = User.objects.prefetch_related('equipped_avatar_items__item')

        if search:
            queryset = queryset.filter(username__icontains=search)

        if liked_only:
            queryset = queryset.filter(favorited_by_relationships__user=current_user)

        likes_subquery = UserFavorite.objects.filter(user=current_user, favorite_user=OuterRef('pk'))

        return queryset.annotate(
            is_liked=Exists(likes_subquery),
            favorites_count=Count('favorited_by_relationships', distinct=True),
            rank=Window(
                expression=Rank(),
                order_by=[F('points').desc(), F('username').asc()],
            )
        ).order_by('-points', 'username')


class UserPublicProfileView(generics.RetrieveAPIView):
    serializer_class = UserPublicProfileSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'username'

    def get_queryset(self):
        current_user = self.request.user
        likes_subquery = UserFavorite.objects.filter(user=current_user, favorite_user=OuterRef('pk'))

        return User.objects.prefetch_related(
            'equipped_avatar_items__item',
            'achievements__achievement',
        ).annotate(
            is_liked=Exists(likes_subquery),
            favorites_count=Count('favorited_by_relationships', distinct=True),
            achievements_total=Count('achievements', distinct=True),
            visited_total=Count('visited_attractions', distinct=True),
            rank=Window(
                expression=Rank(),
                order_by=[F('points').desc(), F('username').asc()],
            ),
        ).order_by('-points', 'username')

    def get_object(self):
        queryset = self.filter_queryset(self.get_queryset())
        username = self.kwargs.get(self.lookup_field)
        return generics.get_object_or_404(queryset, username__iexact=username)


class UserFavoriteToggleView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, username):
        target_user = generics.get_object_or_404(User, username__iexact=username)

        if target_user.pk == request.user.pk:
            return Response({'detail': 'You cannot like yourself.'}, status=status.HTTP_400_BAD_REQUEST)

        favorite, created = UserFavorite.objects.get_or_create(user=request.user, favorite_user=target_user)

        if created:
            is_liked = True
        else:
            favorite.delete()
            is_liked = False

        favorites_count = UserFavorite.objects.filter(favorite_user=target_user).count()
        return Response(
            {
                'username': target_user.username,
                'is_liked': is_liked,
                'favorites_count': favorites_count,
            },
            status=status.HTTP_200_OK,
        )