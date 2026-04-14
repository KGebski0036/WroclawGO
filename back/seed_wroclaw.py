# backend/seed_wroclaw.py
import os
import django
import pandas as pd

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from attractions.models import (
    Attraction,
    AvatarItem,
    Category,
    User,
    UserAvatarItem,
    UserEquippedAvatarItem,
)
from django.contrib.gis.geos import Point

POINTS_MAPPING = {
    "Muzeum": 25,
    "Zabytki": 20,
    "Kościół": 15,
    "Krasnal": 5,
    "Park": 10
}

AVATAR_ITEMS = [
    {
        "tag": "base",
        "name": "Sunset Rouge",
        "svg_path": "avatars/base/sunset-rouge.png",
        "cost": 40,
        "is_default": True,
    },
    {
        "tag": "base",
        "name": "Emerald Haze",
        "svg_path": "avatars/base/emerald-haze.png",
        "cost": 55,
        "is_default": True,
    },
    {
        "tag": "base",
        "name": "Ocean Glow",
        "svg_path": "avatars/base/ocean-glow.png",
        "cost": 65,
        "is_default": True,
    },
    {
        "tag": "base",
        "name": "Blush Pink",
        "svg_path": "avatars/base/blush-pink.png",
        "cost": 75,
        "is_default": True,
    },
    {
        "tag": "base",
        "name": "Midnight Indigo",
        "svg_path": "avatars/base/midnight-indigo.png",
        "cost": 90,
        "is_default": False,
    },
    {
        "tag": "base",
        "name": "Golden Aura",
        "svg_path": "avatars/base/golden-aura.png",
        "cost": 0,
        "is_default": False,
    },
    {
        "tag": "hat",
        "name": "Hat One",
        "svg_path": "avatars/hats/hat_one.svg",
        "cost": 0,
        "is_default": True,
    },
    {
        "tag": "hat",
        "name": "Hat Two",
        "svg_path": "avatars/hats/hat_two.svg",
        "cost": 0,
        "is_default": True,
    },
]

def get_or_create_category(name):
    category, created = Category.objects.get_or_create(name=name)
    
    if created:
        print(f"Utworzono nową kategorię: {name}")
    return category


def read_data(filename, category_name):
    if not os.path.exists(filename):
        print(f"Plik {filename} nie istnieje.")
        return []
    
    data = []
    df = pd.read_csv(filename)
    for _, row in df.iterrows():
        data.append({
            "name": row["nazwa"],
            "lat": float(row["lat"]),
            "lng": float(row["lng"]),
            "category_name": category_name
        })
    return data

def seed_attractions(filename, category_name):
    category_obj = get_or_create_category(category_name)

    reward = POINTS_MAPPING.get(category_name, 10)

    data = read_data(filename, category_name)
    
    for item in data:
        pnt = Point(item['lng'], item['lat'])

        Attraction.objects.get_or_create(
            name=item['name'],
            defaults={
                'location': pnt,
                'category': category_obj,
                'description': f'Zapraszamy do odwiedzenia: {item["name"]}!',
                'points_reward': reward
            }
        )  
            
def create_admin_user():
    if not User.objects.filter(username="admin").exists():
        User.objects.create_superuser("admin", "admin@wroclaw.pl", "admin123")


def seed_avatar_items():
    for payload in AVATAR_ITEMS:
        AvatarItem.objects.update_or_create(
            tag=payload["tag"],
            name=payload["name"],
            defaults=payload,
        )


def sync_user_avatar_defaults():
    defaults = list(AvatarItem.objects.filter(is_default=True).order_by("tag", "id"))

    first_by_tag = {}
    for item in defaults:
        if item.tag not in first_by_tag:
            first_by_tag[item.tag] = item

    for user in User.objects.all().iterator():
        for item in defaults:
            UserAvatarItem.objects.get_or_create(user=user, item=item)

        for tag, item in first_by_tag.items():
            UserEquippedAvatarItem.objects.update_or_create(
                user=user,
                slot=tag,
                defaults={"item": item},
            )

if __name__ == '__main__':
    create_admin_user()
    seed_avatar_items()
    sync_user_avatar_defaults()
    seed_attractions("./dataseed/museums.csv", "Muzeum")
    seed_attractions("./dataseed/zabytki.csv", "Zabytki")
    seed_attractions("./dataseed/kosciol.csv", "Kościół")
    seed_attractions("./dataseed/krasnale.csv", "Krasnal")
    seed_attractions("./dataseed/parks.csv", "Park")