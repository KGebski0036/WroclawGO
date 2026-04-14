import { CommonModule } from '@angular/common';
import { Component, inject, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { take } from 'rxjs';
import { AuthService } from '../../services/auth.service';
import { ShopService } from '../../services/shop.service';
import { AuthUser } from '../../models/auth.model';
import { SkinColor } from '../../models/skin-color.model';

const SKIN_IMAGE_PATH = '/assets/avatar-skins/';
const DEFAULT_SKIN_NAME = 'Golden Aura';

type ShopSkin = SkinColor & {
  owned: boolean;
  active: boolean;
  imageFileName: string;
};

const SHOP_SKIN_DEFINITIONS: Array<{
  name: string;
  imageFileName: string;
  price?: number;
}> = [
  { name: 'Sunset Rouge', imageFileName: 'sunset-rouge.png' },
  { name: 'Emerald Haze', imageFileName: 'emerald-haze.png' },
  { name: 'Ocean Glow', imageFileName: 'ocean-glow.png' },
  { name: 'Blush Pink', imageFileName: 'blush-pink.png' },
  { name: 'Midnight Indigo', imageFileName: 'midnight-indigo.png' },
  { name: DEFAULT_SKIN_NAME, imageFileName: 'golden-aura.png', price: 0 }
];

@Component({
  selector: 'app-avatar-shop',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './avatar-shop.component.html',
  styleUrls: ['./avatar-shop.component.css']
})
export class AvatarShopComponent implements OnInit {
  private readonly shopService = inject(ShopService);
  private readonly authService = inject(AuthService);

  readonly currentUser$ = this.authService.currentUser$;
  currentUser: AuthUser | null = null;
  skinColors: ShopSkin[] = [];
  loading = false;
  errorMessage: string | null = null;

  ngOnInit(): void {
    this.loadSkinColors();
  }

  loadSkinColors(): void {
    this.loading = true;
    this.errorMessage = null;

    this.currentUser$.pipe(take(1)).subscribe((user) => {
      this.currentUser = user;

      this.shopService.getSkinColors().subscribe({
        next: (skins: SkinColor[]) => {
          this.skinColors = this.buildShopSkins(skins, user);
          this.loading = false;
        },
        error: () => {
          this.errorMessage = 'Unable to load skin colors at this time.';
          this.loading = false;
        }
      });
    });
  }

  buildShopSkins(skins: SkinColor[], user: AuthUser | null): ShopSkin[] {
    const normalizedSkins = skins.map((skin) => {
      const name = skin.name === 'Moonlight Silver' ? 'Blush Pink' : skin.name;
      const imageFileName = skin.image_file_name ?? skin.imageFileName ?? `${this.toSlug(name)}.png`;

      return {
        ...skin,
        name,
        price: name === DEFAULT_SKIN_NAME ? 0 : skin.price,
        is_premium: false,
        imageFileName
      } as ShopSkin;
    });

    const skinByName = new Map(normalizedSkins.map((skin) => [skin.name, skin]));

    const filledSkins: ShopSkin[] = SHOP_SKIN_DEFINITIONS.map((definition, index) => {
      const existing = skinByName.get(definition.name);

      return {
        id: existing?.id ?? index + 1,
        name: definition.name,
        color_value: existing?.color_value ?? '',
        price: definition.name === DEFAULT_SKIN_NAME ? 0 : existing?.price ?? definition.price ?? 100,
        image_file_name: existing?.image_file_name,
        imageFileName: existing?.imageFileName ?? definition.imageFileName,
        is_premium: false,
        owned: false,
        active: false
      } as ShopSkin;
    });

    const ownedSkinIds = new Set(user?.owned_skins.map((owned) => owned.id) ?? []);
    const ownedSkinNames = new Set(user?.owned_skins.map((owned) => owned.name) ?? []);
    const selectedSkinId = user?.selected_skin?.id ?? null;
    const selectedSkinName = user?.selected_skin?.name ?? null;

    const activeSkin = selectedSkinId
      ? filledSkins.find((skin) => skin.id === selectedSkinId) ?? filledSkins.find((skin) => skin.name === selectedSkinName)
      : filledSkins.find((skin) => skin.name === DEFAULT_SKIN_NAME);

    const activeSkinId = activeSkin?.id ?? filledSkins.find((skin) => skin.name === DEFAULT_SKIN_NAME)?.id ?? null;

    return filledSkins.map((skin) => ({
      ...skin,
      owned:
        skin.name === DEFAULT_SKIN_NAME ||
        ownedSkinIds.has(skin.id) ||
        ownedSkinNames.has(skin.name) ||
        skin.id === activeSkinId,
      active: skin.id === activeSkinId
    }));
  }

  getSkinImageFileName(skin: ShopSkin): string {
    return skin.imageFileName ?? skin.image_file_name ?? `${this.toSlug(skin.name)}.png`;
  }

  getSkinImageUrl(skin: ShopSkin): string {
    return `${SKIN_IMAGE_PATH}${this.getSkinImageFileName(skin)}`;
  }

  getActiveSkin(): ShopSkin | null {
    return this.skinColors.find((skin) => skin.active) ?? null;
  }

  activeSkinName(): string {
    return this.getActiveSkin()?.name ?? 'No active skin selected yet';
  }

  ownedSkinCount(): number {
    return this.skinColors.filter((skin) => skin.owned).length;
  }

  toSlug(value: string): string {
    return value
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)/g, '');
  }

  isOwned(skin: ShopSkin): boolean {
    return skin.owned;
  }

  isActive(skin: ShopSkin): boolean {
    return skin.active;
  }

  canAfford(user: AuthUser, skin: ShopSkin): boolean {
    return user.points >= (skin.price ?? 0);
  }

  buttonLabel(user: AuthUser, skin: ShopSkin): string {
    if (this.isActive(skin)) {
      return 'Active';
    }

    if (this.isOwned(skin)) {
      return 'Select';
    }

    return this.canAfford(user, skin) ? 'Buy' : 'Not enough points';
  }

  buttonClass(user: AuthUser, skin: ShopSkin): string {
    if (this.isActive(skin)) {
      return 'ghost';
    }

    if (this.isOwned(skin)) {
      return 'secondary';
    }

    return this.canAfford(user, skin) ? 'primary' : 'disabled';
  }

  buttonDisabled(user: AuthUser, skin: ShopSkin): boolean {
    if (this.loading) {
      return true;
    }

    if (this.isActive(skin)) {
      return true;
    }

    if (this.isOwned(skin)) {
      return false;
    }

    return !this.canAfford(user, skin);
  }

  onPrimaryAction(user: AuthUser, skin: ShopSkin): void {
    if (this.isOwned(skin)) {
      this.selectSkin(skin.id);
      return;
    }

    this.purchaseSkin(skin.id);
  }

  purchaseSkin(skinId: number): void {
    this.loading = true;
    this.errorMessage = null;

    this.shopService.purchaseSkin(skinId).subscribe({
      next: () => {
        this.loadSkinColors();
      },
      error: (error) => {
        this.errorMessage = error.error?.detail || 'Purchase failed. Please try again.';
        this.loading = false;
      }
    });
  }

  selectSkin(skinId: number): void {
    this.loading = true;
    this.errorMessage = null;

    this.shopService.selectSkin(skinId).subscribe({
      next: () => {
        this.loadSkinColors();
      },
      error: (error) => {
        this.errorMessage = error.error?.detail || 'Failed to select skin. Please try again.';
        this.loading = false;
      }
    });
  }

  badgeLabel(skin: ShopSkin): string {
    if (this.isActive(skin)) {
      return 'Active';
    }

    if (this.isOwned(skin)) {
      return 'Owned';
    }

    return 'Available';
  }

  badgeClass(skin: ShopSkin): string {
    if (this.isActive(skin)) {
      return 'badge--active';
    }

    if (this.isOwned(skin)) {
      return 'badge--owned';
    }

    return 'badge--premium';
  }
}

