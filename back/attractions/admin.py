from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import Attraction, Category, SkinColor, User, VisitedAttraction


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Game profile', {'fields': ('points', 'profile_picture', 'owned_skins', 'selected_skin')}),
    )
    list_display = ('username', 'email', 'points', 'is_staff')


admin.site.register(Category)
admin.site.register(Attraction)
admin.site.register(SkinColor)
admin.site.register(VisitedAttraction)
