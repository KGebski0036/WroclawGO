# attractions/views.py
from django.db.models import F
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from .models import Attraction, SkinColor, User, VisitedAttraction
from .serializers import (
    AttractionSerializer,
    LoginSerializer,
    RegisterSerializer,
    SkinColorSerializer,
    UserSerializer,
    VisitedAttractionSerializer,
)

class AttractionList(generics.ListAPIView):
    """
    Widok zwracający listę wszystkich atrakcji w formacie GeoJSON.
    """
    queryset = Attraction.objects.all()
    serializer_class = AttractionSerializer
    permission_classes = [permissions.AllowAny]


class VisitAttractionView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, attraction_id):
        attraction = get_object_or_404(Attraction, id=attraction_id)
        visit, created = VisitedAttraction.objects.get_or_create(user=request.user, attraction=attraction)

        if not created:
            return Response({'detail': 'Attraction already visited.'}, status=status.HTTP_400_BAD_REQUEST)

        request.user.points = F('points') + attraction.points_reward
        request.user.save(update_fields=['points'])
        request.user.refresh_from_db()

        return Response(UserSerializer(request.user, context={'request': request}).data)


class VisitedAttractionsView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = VisitedAttractionSerializer

    def get_queryset(self):
        return VisitedAttraction.objects.filter(user=self.request.user).select_related('attraction')


class SkinColorList(generics.ListAPIView):
    queryset = SkinColor.objects.all()
    serializer_class = SkinColorSerializer
    permission_classes = [permissions.IsAuthenticated]


class PurchaseSkinView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, skin_id):
        skin = get_object_or_404(SkinColor, id=skin_id)

        if request.user.owned_skins.filter(id=skin.id).exists():
            return Response({'detail': 'Skin color already owned.'}, status=status.HTTP_400_BAD_REQUEST)

        if request.user.points < skin.price:
            return Response({'detail': 'Not enough points to purchase this skin color.'}, status=status.HTTP_400_BAD_REQUEST)

        request.user.points = F('points') - skin.price
        request.user.save(update_fields=['points'])
        request.user.owned_skins.add(skin)
        request.user.refresh_from_db()

        return Response(UserSerializer(request.user, context={'request': request}).data)


class SelectSkinView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, skin_id):
        skin = get_object_or_404(SkinColor, id=skin_id)

        if not request.user.owned_skins.filter(id=skin.id).exists():
            return Response({'detail': 'Skin color must be owned before selection.'}, status=status.HTTP_400_BAD_REQUEST)

        request.user.selected_skin = skin
        request.user.save(update_fields=['selected_skin'])

        return Response(UserSerializer(request.user, context={'request': request}).data)


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