# attractions/urls.py
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    AchievementListView,
    AttractionList,
    AvatarItemListView,
    CurrentUserView,
    EquipAvatarItemView,
    LoginView,
    LogoutView,
    MarkAttractionVisitedView,
    PurchaseAvatarItemView,
    RegisterView,
    UnmarkAttractionVisitedView,
    UserAchievementListView,
    UserEquippedAvatarItemListView,
    UserAvatarItemListView,
    VisitedAttractionListView,
)

urlpatterns = [
    path('api/attractions/', AttractionList.as_view(), name='attraction-list'),
    path('api/auth/register/', RegisterView.as_view(), name='register'),
    path('api/auth/login/', LoginView.as_view(), name='login'),
    path('api/auth/logout/', LogoutView.as_view(), name='logout'),
    path('api/auth/me/', CurrentUserView.as_view(), name='current-user'),
    path('api/auth/token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
    path('api/avatar/items/', AvatarItemListView.as_view(), name='avatar-item-list'),
    path('api/avatar/my-items/', UserAvatarItemListView.as_view(), name='user-avatar-items'),
    path('api/avatar/my-equipped/', UserEquippedAvatarItemListView.as_view(), name='user-equipped-avatar-items'),
    path('api/avatar/purchase/<int:item_id>/', PurchaseAvatarItemView.as_view(), name='purchase-avatar-item'),
    path('api/avatar/equip/<int:item_id>/', EquipAvatarItemView.as_view(), name='equip-avatar-item'),
    path('api/visited/', VisitedAttractionListView.as_view(), name='visited-attraction-list'),
    path('api/visited/<int:attraction_id>/', MarkAttractionVisitedView.as_view(), name='mark-attraction-visited'),
    path('api/visited/<int:attraction_id>/remove/', UnmarkAttractionVisitedView.as_view(), name='unmark-attraction-visited'),
    path('api/achievements/', AchievementListView.as_view(), name='achievement-list'),
    path('api/achievements/my/', UserAchievementListView.as_view(), name='user-achievement-list'),
]