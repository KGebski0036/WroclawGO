# attractions/urls.py
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    AttractionList,
    CurrentUserView,
    LoginView,
    LogoutView,
    PurchaseSkinView,
    RegisterView,
    SelectSkinView,
    SkinColorList,
    VisitAttractionView,
    VisitedAttractionsView,
)

urlpatterns = [
    path('api/attractions/', AttractionList.as_view(), name='attraction-list'),
    path('api/attractions/visited/', VisitedAttractionsView.as_view(), name='visited-attractions'),
    path('api/attractions/<int:attraction_id>/visit/', VisitAttractionView.as_view(), name='attraction-visit'),
    path('api/shop/skins/', SkinColorList.as_view(), name='skin-list'),
    path('api/shop/skins/<int:skin_id>/purchase/', PurchaseSkinView.as_view(), name='skin-purchase'),
    path('api/shop/skins/<int:skin_id>/select/', SelectSkinView.as_view(), name='skin-select'),
    path('api/auth/register/', RegisterView.as_view(), name='register'),
    path('api/auth/login/', LoginView.as_view(), name='login'),
    path('api/auth/logout/', LogoutView.as_view(), name='logout'),
    path('api/auth/me/', CurrentUserView.as_view(), name='current-user'),
    path('api/auth/token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
]