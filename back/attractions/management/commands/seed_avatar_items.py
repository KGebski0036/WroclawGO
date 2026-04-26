from django.core.management.base import BaseCommand
from attractions.models import AvatarItem, User, UserAvatarItem, UserEquippedAvatarItem


AVATAR_ITEMS = [
    # --- base (first one is default) ---
    {'tag': 'base', 'name': 'Sunset Rouge',    'svg_path': 'avatars/base/sunset-rouge.png',    'cost': 0,   'is_default': True},
    {'tag': 'base', 'name': 'Emerald Haze',    'svg_path': 'avatars/base/emerald-haze.png',    'cost': 50,  'is_default': False},
    {'tag': 'base', 'name': 'Ocean Glow',      'svg_path': 'avatars/base/ocean-glow.png',      'cost': 50,  'is_default': False},
    {'tag': 'base', 'name': 'Blush Pink',      'svg_path': 'avatars/base/blush-pink.png',      'cost': 50,  'is_default': False},
    {'tag': 'base', 'name': 'Midnight Indigo', 'svg_path': 'avatars/base/midnight-indigo.png', 'cost': 50,  'is_default': False},
    {'tag': 'base', 'name': 'Golden Aura',     'svg_path': 'avatars/base/golden-aura.png',     'cost': 100, 'is_default': False},

    # --- eyes (first one is default) ---
    {'tag': 'eyes', 'name': 'Open',  'svg_path': 'avatars/eyes/open.png',  'cost': 0,  'is_default': True},
    {'tag': 'eyes', 'name': 'Wink',  'svg_path': 'avatars/eyes/wink.png',  'cost': 30, 'is_default': False},

    # --- mouth (first one is default) ---
    {'tag': 'mouth', 'name': 'Basic',  'svg_path': 'avatars/mouth/mouth_basic.png',  'cost': 0,  'is_default': True},
    {'tag': 'mouth', 'name': 'Closed', 'svg_path': 'avatars/mouth/mouth_closed.png', 'cost': 20, 'is_default': False},
    {'tag': 'mouth', 'name': 'Smile',  'svg_path': 'avatars/mouth/mouth_smile.png',  'cost': 20, 'is_default': False},

    # --- hair (first one is default) ---
    {'tag': 'hair', 'name': 'Short Blonde',     'svg_path': 'avatars/hair/short_hair_blonde.png',    'cost': 0,   'is_default': True},
    {'tag': 'hair', 'name': 'Short Blue',        'svg_path': 'avatars/hair/short_hair_blue.png',      'cost': 40,  'is_default': False},
    {'tag': 'hair', 'name': 'Short Brown',       'svg_path': 'avatars/hair/short_hair_brown.png',     'cost': 40,  'is_default': False},
    {'tag': 'hair', 'name': 'Two Puffs Blonde',  'svg_path': 'avatars/hair/two_puffs_blonde.png',     'cost': 60,  'is_default': False},
    {'tag': 'hair', 'name': 'Two Puffs Brown',   'svg_path': 'avatars/hair/two_puffs_brown.png',      'cost': 60,  'is_default': False},
    {'tag': 'hair', 'name': 'Two Puffs Dark Blue','svg_path': 'avatars/hair/two_puffs_dark_blue.png', 'cost': 60,  'is_default': False},
    {'tag': 'hair', 'name': 'Two Puffs Purple',  'svg_path': 'avatars/hair/two_puffs_purple.png',     'cost': 60,  'is_default': False},
    {'tag': 'hair', 'name': 'Two Puffs Red',     'svg_path': 'avatars/hair/two_puffs_red.png',        'cost': 60,  'is_default': False},

    # --- pants (first one is default) ---
    {'tag': 'pants', 'name': 'Shorts Brown',     'svg_path': 'avatars/pants/shorts_brown.png',     'cost': 0,  'is_default': True},
    {'tag': 'pants', 'name': 'Shorts Camo',      'svg_path': 'avatars/pants/shorts_camo.png',      'cost': 40, 'is_default': False},
    {'tag': 'pants', 'name': 'Shorts Dark Blue', 'svg_path': 'avatars/pants/shorts_dark_blue.png', 'cost': 40, 'is_default': False},
    {'tag': 'pants', 'name': 'Skirt Blue',       'svg_path': 'avatars/pants/skirt_blue.png',       'cost': 50, 'is_default': False},
    {'tag': 'pants', 'name': 'Skirt Gray',       'svg_path': 'avatars/pants/skirt_gray.png',       'cost': 50, 'is_default': False},
    {'tag': 'pants', 'name': 'Skirt Pink',       'svg_path': 'avatars/pants/skirt_pink.png',       'cost': 50, 'is_default': False},
    {'tag': 'pants', 'name': 'Skirt Purple',     'svg_path': 'avatars/pants/skirt_purple.png',     'cost': 50, 'is_default': False},

    # --- shirts (first one is default) ---
    {'tag': 'shirts', 'name': 'Sleeveless Bow',       'svg_path': 'avatars/shirts/sleeveless_bow.png',      'cost': 0,  'is_default': True},
    {'tag': 'shirts', 'name': 'Sleeveless Clouds',    'svg_path': 'avatars/shirts/sleeveless_clouds.png',   'cost': 40, 'is_default': False},
    {'tag': 'shirts', 'name': 'Sleeveless Frog',      'svg_path': 'avatars/shirts/sleeveless_frog.png',     'cost': 40, 'is_default': False},
    {'tag': 'shirts', 'name': 'Sleeveless Ice Cream', 'svg_path': 'avatars/shirts/sleeveless_icecream.png', 'cost': 40, 'is_default': False},
    {'tag': 'shirts', 'name': 'T-Shirt Bow',          'svg_path': 'avatars/shirts/tshirt_bow.png',          'cost': 50, 'is_default': False},
    {'tag': 'shirts', 'name': 'T-Shirt Clouds',       'svg_path': 'avatars/shirts/tshirt_clouds.png',       'cost': 50, 'is_default': False},
    {'tag': 'shirts', 'name': 'T-Shirt Frog',         'svg_path': 'avatars/shirts/tshirt_frog.png',         'cost': 50, 'is_default': False},
    {'tag': 'shirts', 'name': 'T-Shirt Ice Cream',    'svg_path': 'avatars/shirts/tshirt_icecream.png',     'cost': 50, 'is_default': False},

    # --- background (first one is default) ---
    {'tag': 'background', 'name': 'Pink',              'svg_path': 'avatars/background/background_pink.png',              'cost': 0,  'is_default': True},
    {'tag': 'background', 'name': 'Sky',               'svg_path': 'avatars/background/background_sky.png',               'cost': 30, 'is_default': False},
    {'tag': 'background', 'name': 'Sky Clouds',        'svg_path': 'avatars/background/background_sky_clouds.png',        'cost': 50, 'is_default': False},
    {'tag': 'background', 'name': 'Strawberry Pattern','svg_path': 'avatars/background/background_strawberry_pattern.png','cost': 60, 'is_default': False},
]


class Command(BaseCommand):
    help = 'Sync AvatarItems to match current static files and ensure all users have default items.'

    def handle(self, *args, **options):
        self.stdout.write('Syncing avatar items...')

        known_paths = set()
        for data in AVATAR_ITEMS:
            item, created = AvatarItem.objects.update_or_create(
                svg_path=data['svg_path'],
                defaults=data,
            )
            known_paths.add(data['svg_path'])
            status = 'created' if created else 'updated'
            self.stdout.write(f'  {status}: [{item.tag}] {item.name}')

        # Remove stale items whose files no longer exist
        stale = AvatarItem.objects.exclude(svg_path__in=known_paths)
        stale_count = stale.count()
        if stale_count:
            self.stdout.write(f'Removing {stale_count} stale avatar item(s)...')
            stale.delete()

        # Ensure every user owns and equips the default items
        defaults = list(AvatarItem.objects.filter(is_default=True).order_by('tag', 'id'))
        first_by_tag = {}
        for item in defaults:
            if item.tag not in first_by_tag:
                first_by_tag[item.tag] = item

        for user in User.objects.all():
            for item in defaults:
                UserAvatarItem.objects.get_or_create(user=user, item=item)

            for tag, item in first_by_tag.items():
                equipped = UserEquippedAvatarItem.objects.filter(user=user, slot=tag).first()
                if not equipped:
                    UserEquippedAvatarItem.objects.create(user=user, item=item, slot=tag)

        self.stdout.write(self.style.SUCCESS('Done.'))
