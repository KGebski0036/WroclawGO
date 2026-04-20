import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { UserEquippedAvatarItem } from '../../models/avatar.model';
import { AvatarService } from '../../services/avatar.service';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-avatar-placeholder',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './avatar-placeholder.component.html',
  styleUrl: './avatar-placeholder.component.css'
})
export class AvatarPlaceholderComponent {
  private readonly authService = inject(AuthService);
  readonly avatarService = inject(AvatarService);
  readonly currentUser$ = this.authService.currentUser$;
  readonly equippedItems$ = this.avatarService.getEquippedItems();

  readonly plannedTrips = [
    { name: 'Old Town route', eta: 'Tomorrow', points: 35 },
    { name: 'Island bridges walk', eta: 'In 3 days', points: 25 },
    { name: 'Hidden courtyards', eta: 'Weekend', points: 40 }
  ];

  readonly achievements = [
    { name: 'First Steps', detail: 'Visited your first attraction' },
    { name: 'Curious Explorer', detail: 'Read 5 attraction stories' },
    { name: 'Route Builder', detail: 'Created 3 custom map routes' },
    { name: 'Route Builder', detail: 'Created 3 custom map routes' }
  ];

  readonly visitedPreview = [
    { name: 'Panorama of Raclawice', date: '2026-03-18', points: 20 },
    { name: 'Wroclaw Market Square', date: '2026-03-19', points: 15 },
    { name: 'Cathedral Island', date: '2026-03-24', points: 30 },
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

  getOrderedEquippedItems(items: UserEquippedAvatarItem[]): UserEquippedAvatarItem[] {
    const slotOrder: Record<string, number> = {
      base: 0,
      skin_color: 0,
      hat: 10,
      glasses: 20
    };

    return [...items].sort((a, b) => {
      const left = slotOrder[a.slot] ?? 100;
      const right = slotOrder[b.slot] ?? 100;
      return left - right;
    });
  }

  getLayerStyle(slot: string): Record<string, string> {
    const styleBySlot: Record<string, Record<string, string>> = {
      base: { transform: 'translate(0, 0) scale(1)' },
      skin_color: { transform: 'translate(0, 0) scale(1)' },
      hat: { transform: 'translateY(-38%) scale(0.5)' },
      glasses: { transform: 'translateY(-2%) scale(1)' }
    };

    return styleBySlot[slot] ?? { transform: 'translate(0, 0) scale(1)' };
  }
}
