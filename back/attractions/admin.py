from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import Achievement, Attraction, AvatarItem, Category, User, UserAchievement, UserAvatarItem, UserEquippedAvatarItem, VisitedAttraction


@admin.register(User)
class UserAdmin(BaseUserAdmin):
	fieldsets = BaseUserAdmin.fieldsets + (
		('Game profile', {'fields': ('points', 'profile_picture')}),
	)
	list_display = ('id', 'username', 'email', 'points', 'is_staff')


@admin.register(AvatarItem)
class AvatarItemAdmin(admin.ModelAdmin):
	list_display = ('name', 'tag', 'cost', 'is_default', 'svg_path')
	list_filter = ('tag', 'is_default')
	search_fields = ('name', 'tag')


@admin.register(UserAvatarItem)
class UserAvatarItemAdmin(admin.ModelAdmin):
	list_display = ('user', 'item', 'unlocked_at')
	list_filter = ('item__tag',)
	search_fields = ('user__username', 'item__name')
	raw_id_fields = ('user', 'item')


@admin.register(UserEquippedAvatarItem)
class UserEquippedAvatarItemAdmin(admin.ModelAdmin):
	list_display = ('user', 'slot', 'item', 'updated_at')
	list_filter = ('slot',)
	search_fields = ('user__username', 'item__name', 'slot')
	raw_id_fields = ('user', 'item')


admin.site.register(Category)


@admin.register(Attraction)
class AttractionAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'category', 'points_reward')
    search_fields = ('name',)
    list_filter = ('category',)


@admin.register(VisitedAttraction)
class VisitedAttractionAdmin(admin.ModelAdmin):
    list_display = ('user', 'attraction', 'visited_at')
    list_filter = ('attraction__category',)
    search_fields = ('user__username', 'attraction__name')
    raw_id_fields = ('user', 'attraction')


@admin.register(Achievement)
class AchievementAdmin(admin.ModelAdmin):
    list_display = ('id', 'name', 'points_reward', 'badge_path')
    search_fields = ('name',)


@admin.register(UserAchievement)
class UserAchievementAdmin(admin.ModelAdmin):
    list_display = ('user', 'achievement', 'earned_at')
    search_fields = ('user__username', 'achievement__name')
    raw_id_fields = ('user', 'achievement')
