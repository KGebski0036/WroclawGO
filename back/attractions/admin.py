from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import Attraction, AvatarItem, Category, User, UserAvatarItem, UserEquippedAvatarItem


@admin.register(User)
class UserAdmin(BaseUserAdmin):
	fieldsets = BaseUserAdmin.fieldsets + (
		('Game profile', {'fields': ('points', 'profile_picture')}),
	)
	list_display = ('username', 'email', 'points', 'is_staff')


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
admin.site.register(Attraction)
