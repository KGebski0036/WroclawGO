import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { map } from 'rxjs';
import { AuthService } from '../../services/auth.service';
import { ShopService } from '../../services/shop.service';
import { AuthUser } from '../../models/auth.model';

@Component({
  selector: 'app-avatar-placeholder',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './avatar-placeholder.component.html',
  styleUrl: './avatar-placeholder.component.css'
})
export class AvatarPlaceholderComponent {
  private readonly authService = inject(AuthService);
  private readonly shopService = inject(ShopService);

  readonly currentUser$ = this.authService.currentUser$;
  readonly activeSkin$ = this.currentUser$.pipe(map((user) => this.getActiveSkinFromUser(user)));
  selectingSkin = false;
  skinError: string | null = null;

  readonly plannedTrips = [
    { name: 'Old Town route', eta: 'Tomorrow', points: 35 },
    { name: 'Island bridges walk', eta: 'In 3 days', points: 25 },
    { name: 'Hidden courtyards', eta: 'Weekend', points: 40 }
  ];

  readonly achievements = [
    { name: 'First Steps', detail: 'Visited your first attraction' },
    { name: 'Curious Explorer', detail: 'Read 5 attraction stories' },
    { name: 'Route Builder', detail: 'Created 3 custom map routes' }
  ];

  readonly visitedPreview = [
    { name: 'Panorama of Raclawice', date: '2026-03-18', points: 20 },
    { name: 'Wroclaw Market Square', date: '2026-03-19', points: 15 },
    { name: 'Cathedral Island', date: '2026-03-24', points: 30 }
  ];

  getInitials(username: string): string {
    return username.slice(0, 2).toUpperCase();
  }

  getLevel(points: number): number {
    return Math.floor(points / 100) + 1;
  }

  getPointsToNextLevel(points: number): number {
    const remainder = points % 100;
    return remainder === 0 ? 100 : 100 - remainder;
  }

  getLevelProgress(points: number): number {
    return points % 100;
  }

  getStatusLabel(points: number): string {
    if (points >= 500) {
      return 'City Legend';
    }

    if (points >= 250) {
      return 'Advanced Explorer';
    }

    if (points >= 100) {
      return 'Explorer';
    }

    return 'Rookie Traveler';
  }

  private getActiveSkinFromUser(user: AuthUser | null): AuthUser['selected_skin'] | null {
    if (!user) {
      return null;
    }

    if (user.selected_skin) {
      return user.selected_skin;
    }

    return user.owned_skins.find((skin) => skin.name === 'Golden Aura') ?? null;
  }

  isOwned(user: AuthUser, skinId: number): boolean {
    return user.owned_skins.some((skin) => skin.id === skinId);
  }

  selectSkin(skinId: number): void {
    this.selectingSkin = true;
    this.skinError = null;

    this.shopService.selectSkin(skinId).subscribe({
      next: () => {
        this.authService.fetchCurrentUser().subscribe();
        this.selectingSkin = false;
      },
      error: (error) => {
        this.skinError = error.error?.detail || 'Unable to select this skin.';
        this.selectingSkin = false;
      }
    });
  }
}
