from django.contrib.gis.db import models
from django.contrib.auth.models import AbstractUser

class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)

    class Meta:
        verbose_name_plural = "Categories"

    def __str__(self):
        return self.name

class SkinColor(models.Model):
    name = models.CharField(max_length=100, unique=True)
    color_value = models.CharField(max_length=7)
    price = models.PositiveIntegerField(default=50)
    image_file_name = models.CharField(max_length=255, default='default.png', help_text='Filename for the skin preview image')
    is_premium = models.BooleanField(default=False, help_text='If True, this skin cannot be purchased and is given to all users')

    class Meta:
        verbose_name = 'Skin Color'
        verbose_name_plural = 'Skin Colors'

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
    owned_skins = models.ManyToManyField(SkinColor, blank=True, related_name='owners')
    selected_skin = models.ForeignKey(SkinColor, null=True, blank=True, on_delete=models.SET_NULL, related_name='selected_by')

    def __str__(self):
        return self.username

class VisitedAttraction(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='visited_attractions')
    attraction = models.ForeignKey(Attraction, on_delete=models.CASCADE, related_name='visits')
    visited_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'attraction')
        ordering = ['-visited_at']

    def __str__(self):
        return f"{self.user.username} visited {self.attraction.name}"