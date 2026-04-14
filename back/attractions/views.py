# attractions/views.py
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from .models import Attraction, AvatarItem, UserAvatarItem, UserEquippedAvatarItem
from .serializers import (
    AttractionSerializer,
    AvatarItemSerializer,
    LoginSerializer,
    RegisterSerializer,
    UserAvatarItemSerializer,
    UserEquippedAvatarItemSerializer,
    UserSerializer,
)

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