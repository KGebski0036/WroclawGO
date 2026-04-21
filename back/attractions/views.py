from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import (
    Achievement,
    Attraction,
    AvatarItem,
    UserAchievement,
    UserAvatarItem,
    UserEquippedAvatarItem,
    VisitedAttraction,
)
from .serializers import (
    AchievementSerializer,
    AttractionSerializer,
    AvatarItemSerializer,
    LoginSerializer,
    RegisterSerializer,
    UserAchievementSerializer,
    UserAvatarItemSerializer,
    UserEquippedAvatarItemSerializer,
    UserSerializer,
    VisitedAttractionSerializer,
)
from .achievement_service import check_achievements


class AttractionList(generics.ListAPIView):
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
            return Response(
                {'detail': 'Refresh token is required for logout.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

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
    queryset = AvatarItem.objects.all().order_by('tag', 'cost', 'id')
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
        return (
            UserEquippedAvatarItem.objects
            .filter(user=self.request.user)
            .select_related('item')
            .order_by('slot', 'id')
        )


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


class UnequipAvatarItemView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, slot):
        protected_slots = {'base', 'background'}
        if slot in protected_slots:
            return Response(
                {'detail': f'Items in slot "{slot}" cannot be removed.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        deleted_count, _ = UserEquippedAvatarItem.objects.filter(
            user=request.user,
            slot=slot,
        ).delete()

        if deleted_count == 0:
            return Response({'detail': 'No equipped item found for this slot.'}, status=status.HTTP_404_NOT_FOUND)

        return Response(status=status.HTTP_204_NO_CONTENT)


class VisitedAttractionListView(generics.ListAPIView):
    serializer_class = VisitedAttractionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            VisitedAttraction.objects
            .filter(user=self.request.user)
            .select_related('attraction')
            .order_by('-visited_at')
        )


class MarkAttractionVisitedView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, attraction_id):
        try:
            attraction = Attraction.objects.get(pk=attraction_id)
        except Attraction.DoesNotExist:
            return Response({'detail': 'Attraction not found.'}, status=status.HTTP_404_NOT_FOUND)

        if VisitedAttraction.objects.filter(user=request.user, attraction=attraction).exists():
            return Response(
                {'detail': 'Attraction already marked as visited.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        visited = VisitedAttraction.objects.create(user=request.user, attraction=attraction)

        request.user.points += attraction.points_reward
        request.user.save(update_fields=['points'])

        newly_earned = check_achievements(request.user)

        return Response(
            {
                'visited': VisitedAttractionSerializer(visited).data,
                'newly_earned': AchievementSerializer(newly_earned, many=True).data,
            },
            status=status.HTTP_201_CREATED,
        )


class UnmarkAttractionVisitedView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, attraction_id):
        try:
            visited = VisitedAttraction.objects.get(user=request.user, attraction_id=attraction_id)
        except VisitedAttraction.DoesNotExist:
            return Response({'detail': 'Visited record not found.'}, status=status.HTTP_404_NOT_FOUND)

        points_to_deduct = visited.attraction.points_reward
        visited.delete()

        request.user.points = max(0, request.user.points - points_to_deduct)
        request.user.save(update_fields=['points'])

        return Response(status=status.HTTP_204_NO_CONTENT)


class AchievementListView(generics.ListAPIView):
    queryset = Achievement.objects.all().order_by('id')
    serializer_class = AchievementSerializer
    permission_classes = [permissions.IsAuthenticated]


class UserAchievementListView(generics.ListAPIView):
    serializer_class = UserAchievementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return (
            UserAchievement.objects
            .filter(user=self.request.user)
            .select_related('achievement')
            .order_by('-earned_at')
        )
