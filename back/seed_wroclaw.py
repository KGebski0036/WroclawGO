# backend/seed_wroclaw.py
import os
import django
import pandas as pd

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from attractions.models import Attraction, Category, SkinColor, User
from django.contrib.gis.geos import Point

POINTS_MAPPING = {
    "Muzeum": 25,
    "Zabytki": 20,
    "Kościół": 15,
    "Krasnal": 5,
    "Park": 10
}

SKIN_COLORS = [
    {"name": "Sunset Rouge", "color_value": "#d9534f", "price": 40, "image_file_name": "sunset-rouge.png", "is_premium": False},
    {"name": "Emerald Haze", "color_value": "#27ae60", "price": 55, "image_file_name": "emerald-haze.png", "is_premium": False},
    {"name": "Ocean Glow", "color_value": "#3498db", "price": 65, "image_file_name": "ocean-glow.png", "is_premium": False},
    {"name": "Blush Pink", "color_value": "#ff69b4", "price": 75, "image_file_name": "blush-pink.png", "is_premium": False},
    {"name": "Midnight Indigo", "color_value": "#34495e", "price": 90, "image_file_name": "midnight-indigo.png", "is_premium": False},
    {"name": "Golden Aura", "color_value": "#f39c12", "price": 0, "image_file_name": "golden-aura.png", "is_premium": True}
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


def seed_skin_colors():
    for skin_data in SKIN_COLORS:
        SkinColor.objects.get_or_create(
            name=skin_data['name'],
            defaults={
                'color_value': skin_data['color_value'],
                'price': skin_data['price'],
                'image_file_name': skin_data['image_file_name'],
                'is_premium': skin_data['is_premium']
            }
        )


def create_admin_user():
    if not User.objects.filter(username="admin").exists():
        User.objects.create_superuser("admin", "admin@wroclaw.pl", "admin123")

if __name__ == '__main__':
    create_admin_user()
    seed_attractions("./dataseed/museums.csv", "Muzeum")
    seed_attractions("./dataseed/zabytki.csv", "Zabytki")
    seed_attractions("./dataseed/kosciol.csv", "Kościół")
    seed_attractions("./dataseed/krasnale.csv", "Krasnal")
    seed_attractions("./dataseed/parks.csv", "Park")
    seed_skin_colors()