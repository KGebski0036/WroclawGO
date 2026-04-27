import os
import django
from django.test import tag
import pandas as pd

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from attractions.models import (
    Achievement,
    Attraction,
    AvatarItem,
    Category,
    User,
    UserAvatarItem,
    UserEquippedAvatarItem,
)
from django.contrib.gis.geos import Point

POINTS_MAPPING = { "Muzeum": 25, "Zabytki": 20, "Kościół": 15, "Krasnal": 5, "Park": 10, }




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
            "description": row.get("opis", ""),
            "category_name": category_name,
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
            description=item['description'],
            defaults={
                'location': pnt,
                'category': category_obj,
                'points_reward': reward,
            },
        )


def create_admin_user():
    if not User.objects.filter(username="admin").exists():
        User.objects.create_superuser("admin", "admin@wroclaw.pl", "admin123")


def seed_avatar_items():
    filename = "./dataseed/avatar_items.csv"
    
    if not os.path.exists(filename):
        print(f"Plik {filename} nie istnieje.")
        return []

    data = []
    df = pd.read_csv(filename)
    for _, row in df.iterrows():
        data.append({
            "tag": row["tag"],
            "name": row["name"],
            "svg_path": row["svg_path"],
            "cost": float(row["cost"]),
            "is_default": bool(row["is_default"]),
        })
    for payload in data:
        AvatarItem.objects.update_or_create(
            tag=payload["tag"],
            name=payload["name"],
            defaults=payload,
        )


def sync_user_avatar_defaults():
    defaults = list(AvatarItem.objects.filter(is_default=True).order_by("tag", "id"))

    for user in User.objects.all().iterator():
        for item in defaults:
            UserAvatarItem.objects.get_or_create(user=user, item=item)

        golden_base = AvatarItem.objects.filter(tag="base", name="Golden Aura").first()
        sky_background = AvatarItem.objects.filter(tag="background", name="Sky Background").first()

        if golden_base:
            UserEquippedAvatarItem.objects.update_or_create(
                user=user,
                slot="base",
                defaults={"item": golden_base},
            )

        if sky_background:
            UserEquippedAvatarItem.objects.update_or_create(
                user=user,
                slot="background",
                defaults={"item": sky_background},
            )


def seed_achievements():
    filename = "./dataseed/achievements.csv"
    
    if not os.path.exists(filename):
        print(f"Plik {filename} nie istnieje.")
        return []
    data = []
    df = pd.read_csv(filename)
    for _, row in df.iterrows():
        data.append({
            "name": row["name"],
            "description": row["description"],
            "badge_path": row["badge_path"],
            "points_reward": float(row["points_reward"]),
        })
    for payload in data:
        Achievement.objects.update_or_create(
            name=payload["name"],
            defaults=payload,
        )


if __name__ == '__main__':
    create_admin_user()
    seed_achievements()
    seed_avatar_items()
    sync_user_avatar_defaults()

    seed_attractions("./dataseed/museums.csv", "Muzeum")
    seed_attractions("./dataseed/zabytki.csv", "Zabytki")
    seed_attractions("./dataseed/kosciol.csv", "Kościół")
    seed_attractions("./dataseed/krasnale.csv", "Krasnal")
    seed_attractions("./dataseed/parks.csv", "Park")
