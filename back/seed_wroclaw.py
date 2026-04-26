import os
import django
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

POINTS_MAPPING = {
    "Muzeum": 25,
    "Zabytki": 20,
    "Kościół": 15,
    "Krasnal": 5,
    "Park": 10,
}

ACHIEVEMENTS = [
    {
        "name": "First Steps",
        "description": "Visit your first attraction.",
        "badge_path": "achievements/first_steps.svg",
        "points_reward": 10,
    },
    {
        "name": "Tourist",
        "description": "Visit 4 attractions.",
        "badge_path": "achievements/tourist.svg",
        "points_reward": 20,
    },
    {
        "name": "Explorer",
        "description": "Visit 10 attractions.",
        "badge_path": "achievements/explorer.svg",
        "points_reward": 40,
    },
    {
        "name": "Adventurer",
        "description": "Visit 25 attractions.",
        "badge_path": "achievements/adventurer.svg",
        "points_reward": 80,
    },
    {
        "name": "Traveler",
        "description": "Visit 50 attractions.",
        "badge_path": "achievements/traveler.svg",
        "points_reward": 150,
    },
    {
        "name": "Dwarf Hunter",
        "description": "Visit 20 dwarfs around Wroclaw.",
        "badge_path": "achievements/dwarf_hunter.svg",
        "points_reward": 60,
    },
    {
        "name": "Dwarf Master",
        "description": "Visit all dwarfs in Wroclaw.",
        "badge_path": "achievements/dwarf_master.svg",
        "points_reward": 120,
    },
    {
        "name": "Museum Enthusiast",
        "description": "Visit 3 museums.",
        "badge_path": "achievements/museum_enthusiast.svg",
        "points_reward": 30,
    },
    {
        "name": "Nature Walker",
        "description": "Visit 3 parks.",
        "badge_path": "achievements/nature_walker.svg",
        "points_reward": 30,
    },
    {
        "name": "Monument Hunter",
        "description": "Visit 5 monuments.",
        "badge_path": "achievements/monument_hunter.svg",
        "points_reward": 50,
    },
]

AVATAR_ITEMS = [
    {
        "tag": "background",
        "name": "Pink Background",
        "svg_path": "avatars/background/background_pink.png",
        "cost": 0,
        "is_default": True,
    },
    {
        "tag": "background",
        "name": "Sky Background",
        "svg_path": "avatars/background/background_sky.png",
        "cost": 0,
        "is_default": True,
    },
    {
        "tag": "background",
        "name": "Sky Clouds Background",
        "svg_path": "avatars/background/background_sky_clouds.png",
        "cost": 35,
        "is_default": False,
    },
    {
        "tag": "background",
        "name": "Strawberry Background",
        "svg_path": "avatars/background/background_strawberry_pattern.png",
        "cost": 45,
        "is_default": False,
    },

    {
        "tag": "base",
        "name": "Golden Aura",
        "svg_path": "avatars/base/golden-aura.png",
        "cost": 0,
        "is_default": True,
    },
    {
        "tag": "base",
        "name": "Sunset Rouge",
        "svg_path": "avatars/base/sunset-rouge.png",
        "cost": 40,
        "is_default": False,
    },
    {
        "tag": "base",
        "name": "Emerald Haze",
        "svg_path": "avatars/base/emerald-haze.png",
        "cost": 55,
        "is_default": False,
    },
    {
        "tag": "base",
        "name": "Ocean Glow",
        "svg_path": "avatars/base/ocean-glow.png",
        "cost": 65,
        "is_default": False,
    },
    {
        "tag": "base",
        "name": "Blush Pink",
        "svg_path": "avatars/base/blush-pink.png",
        "cost": 75,
        "is_default": False,
    },
    {
        "tag": "base",
        "name": "Midnight Indigo",
        "svg_path": "avatars/base/midnight-indigo.png",
        "cost": 90,
        "is_default": False,
    },

    {
        "tag": "eyes",
        "name": "Open Eyes",
        "svg_path": "avatars/eyes/open.png",
        "cost": 15,
        "is_default": False,
    },
    {
        "tag": "eyes",
        "name": "Wink Eyes",
        "svg_path": "avatars/eyes/wink.png",
        "cost": 20,
        "is_default": False,
    },

    {
        "tag": "mouth",
        "name": "Basic Mouth",
        "svg_path": "avatars/mouth/mouth_basic.png",
        "cost": 12,
        "is_default": False,
    },
    {
        "tag": "mouth",
        "name": "Closed Mouth",
        "svg_path": "avatars/mouth/mouth_closed.png",
        "cost": 14,
        "is_default": False,
    },
    {
        "tag": "mouth",
        "name": "Smile Mouth",
        "svg_path": "avatars/mouth/mouth_smile.png",
        "cost": 18,
        "is_default": False,
    },

    {
        "tag": "pants",
        "name": "Brown Shorts",
        "svg_path": "avatars/pants/shorts_brown.png",
        "cost": 18,
        "is_default": False,
    },
    {
        "tag": "pants",
        "name": "Camo Shorts",
        "svg_path": "avatars/pants/shorts_camo.png",
        "cost": 22,
        "is_default": False,
    },
    {
        "tag": "pants",
        "name": "Dark Blue Shorts",
        "svg_path": "avatars/pants/shorts_dark_blue.png",
        "cost": 20,
        "is_default": False,
    },
    {
        "tag": "pants",
        "name": "Blue Skirt",
        "svg_path": "avatars/pants/skirt_blue.png",
        "cost": 20,
        "is_default": False,
    },
    {
        "tag": "pants",
        "name": "Gray Skirt",
        "svg_path": "avatars/pants/skirt_gray.png",
        "cost": 20,
        "is_default": False,
    },
    {
        "tag": "pants",
        "name": "Pink Skirt",
        "svg_path": "avatars/pants/skirt_pink.png",
        "cost": 20,
        "is_default": False,
    },
    {
        "tag": "pants",
        "name": "Purple Skirt",
        "svg_path": "avatars/pants/skirt_purple.png",
        "cost": 24,
        "is_default": False,
    },

    {
        "tag": "shirts",
        "name": "Sleeveless Bow",
        "svg_path": "avatars/shirts/sleeveless_bow.png",
        "cost": 24,
        "is_default": False,
    },
    {
        "tag": "shirts",
        "name": "Sleeveless Clouds",
        "svg_path": "avatars/shirts/sleeveless_clouds.png",
        "cost": 24,
        "is_default": False,
    },
    {
        "tag": "shirts",
        "name": "Sleeveless Frog",
        "svg_path": "avatars/shirts/sleeveless_frog.png",
        "cost": 24,
        "is_default": False,
    },
    {
        "tag": "shirts",
        "name": "Sleeveless Icecream",
        "svg_path": "avatars/shirts/sleeveless_icecream.png",
        "cost": 24,
        "is_default": False,
    },
    {
        "tag": "shirts",
        "name": "Tshirt Bow",
        "svg_path": "avatars/shirts/tshirt_bow.png",
        "cost": 26,
        "is_default": False,
    },
    {
        "tag": "shirts",
        "name": "Tshirt Clouds",
        "svg_path": "avatars/shirts/tshirt_clouds.png",
        "cost": 26,
        "is_default": False,
    },
    {
        "tag": "shirts",
        "name": "Tshirt Frog",
        "svg_path": "avatars/shirts/tshirt_frog.png",
        "cost": 26,
        "is_default": False,
    },
    {
        "tag": "shirts",
        "name": "Tshirt Icecream",
        "svg_path": "avatars/shirts/tshirt_icecream.png",
        "cost": 26,
        "is_default": False,
    },

    {
        "tag": "hair",
        "name": "Short Hair Blonde",
        "svg_path": "avatars/hair/short_hair_blonde.png",
        "cost": 20,
        "is_default": False,
    },
    {
        "tag": "hair",
        "name": "Short Hair Blue",
        "svg_path": "avatars/hair/short_hair_blue.png",
        "cost": 20,
        "is_default": False,
    },
    {
        "tag": "hair",
        "name": "Short Hair Brown",
        "svg_path": "avatars/hair/short_hair_brown.png",
        "cost": 20,
        "is_default": False,
    },
    {
        "tag": "hair",
        "name": "Two Puffs Blonde",
        "svg_path": "avatars/hair/two_puffs_blonde.png",
        "cost": 24,
        "is_default": False,
    },
    {
        "tag": "hair",
        "name": "Two Puffs Brown",
        "svg_path": "avatars/hair/two_puffs_brown.png",
        "cost": 24,
        "is_default": False,
    },
    {
        "tag": "hair",
        "name": "Two Puffs Dark Blue",
        "svg_path": "avatars/hair/two_puffs_dark_blue.png",
        "cost": 24,
        "is_default": False,
    },
    {
        "tag": "hair",
        "name": "Two Puffs Purple",
        "svg_path": "avatars/hair/two_puffs_purple.png",
        "cost": 24,
        "is_default": False,
    },
    {
        "tag": "hair",
        "name": "Two Puffs Red",
        "svg_path": "avatars/hair/two_puffs_red.png",
        "cost": 24,
        "is_default": False,
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
            defaults={
                'location': pnt,
                'category': category_obj,
                'description': f'Zapraszamy do odwiedzenia: {item["name"]}!',
                'points_reward': reward,
            },
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
    for payload in ACHIEVEMENTS:
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
