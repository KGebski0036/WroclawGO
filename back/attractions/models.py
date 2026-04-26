from django.contrib.gis.db import models
from django.contrib.auth.models import AbstractUser
from django.db.models import Q
from django.db.models.signals import post_save
from django.dispatch import receiver


class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)

    class Meta:
        verbose_name_plural = "Categories"

    def __str__(self):
        return self.name


class Attraction(models.Model):
    name = models.CharField(max_length=200)
    description = models.TextField()
    location = models.PointField(srid=4326)
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, related_name='attractions')
    points_reward = models.IntegerField(default=10)

    def __str__(self):
        return self.name


class User(AbstractUser):
    email = models.EmailField(unique=True)
    points = models.IntegerField(default=0)
    profile_picture = models.ImageField(upload_to='profile_pics/', null=True, blank=True)

    def __str__(self):
        return self.username


class AvatarItem(models.Model):
    tag = models.CharField(max_length=50)
    name = models.CharField(max_length=100)
    svg_path = models.CharField(max_length=255)
    cost = models.IntegerField(default=0)
    is_default = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.tag} — {self.name}"


class UserAvatarItem(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='avatar_items')
    item = models.ForeignKey(AvatarItem, on_delete=models.CASCADE, related_name='owners')
    unlocked_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'item')

    def __str__(self):
        return f"{self.user.username} — {self.item.name}"


class UserEquippedAvatarItem(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='equipped_avatar_items')
    item = models.ForeignKey(AvatarItem, on_delete=models.CASCADE, related_name='equipped_by')
    slot = models.CharField(max_length=50)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = (('user', 'slot'), ('user', 'item'))

    def save(self, *args, **kwargs):
        self.slot = self.item.tag
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.user.username} [{self.slot}] — {self.item.name}"


class UserFavorite(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='favorite_relationships')
    favorite_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='favorited_by_relationships')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'favorite_user')
        constraints = [
            models.CheckConstraint(
                check=~Q(user=models.F('favorite_user')),
                name='prevent_self_favorite',
            )
        ]

    def __str__(self):
        return f"{self.user.username} -> {self.favorite_user.username}"


class Achievement(models.Model):
    name = models.CharField(max_length=200)
    description = models.TextField()
    badge_path = models.CharField(max_length=255)
    points_reward = models.IntegerField(default=0)

    def __str__(self):
        return self.name


class UserAchievement(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='achievements')
    achievement = models.ForeignKey(Achievement, on_delete=models.CASCADE, related_name='earners')
    earned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'achievement')

    def __str__(self):
        return f"{self.user.username} — {self.achievement.name}"


class VisitedAttraction(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='visited_attractions')
    attraction = models.ForeignKey(Attraction, on_delete=models.CASCADE, related_name='visited_by')
    visited_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'attraction')

    def __str__(self):
        return f"{self.user.username} — {self.attraction.name}"


@receiver(post_save, sender=User)
def unlock_default_items(sender, instance, created, **kwargs):
    if created:
        defaults = AvatarItem.objects.filter(is_default=True).order_by('tag', 'id')
        UserAvatarItem.objects.bulk_create(
            [UserAvatarItem(user=instance, item=item) for item in defaults],
            ignore_conflicts=True,
        )

        equipped_defaults = {}
        for item in defaults:
            if item.tag not in equipped_defaults:
                equipped_defaults[item.tag] = item

        UserEquippedAvatarItem.objects.bulk_create(
            [
                UserEquippedAvatarItem(user=instance, item=item, slot=item.tag)
                for item in equipped_defaults.values()
            ],
            ignore_conflicts=True,
        )


@receiver(post_save, sender='attractions.VisitedAttraction')
def on_visited_attraction_saved(sender, instance, created, **kwargs):
    if created:
        user = instance.user
        User.objects.filter(pk=user.pk).update(
            points=models.F('points') + instance.attraction.points_reward
        )
        from .achievement_service import check_achievements
        check_achievements(user)