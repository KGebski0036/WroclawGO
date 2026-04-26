import { CommonModule } from '@angular/common';
import { Component, inject, OnDestroy, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { Subscription, timer } from 'rxjs';
import { switchMap } from 'rxjs/operators';
import { UserEquippedAvatarItem } from '../../models/avatar.model';
import { VisitedAttraction } from '../../models/attraction.model';
import { UserAchievement } from '../../models/achievement.model';
import { AvatarService } from '../../services/avatar.service';
import { AuthService } from '../../services/auth.service';
import { AttractionService } from '../../services/attraction.service';
import { AchievementService } from '../../services/achievement.service';

@Component({
  selector: 'app-avatar-placeholder',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './avatar-placeholder.component.html',
  styleUrl: './avatar-placeholder.component.css'
})
export class AvatarPlaceholderComponent implements OnInit, OnDestroy {
  private readonly authService = inject(AuthService);
  private readonly attractionService = inject(AttractionService);
  private readonly achievementService = inject(AchievementService);
  readonly avatarService = inject(AvatarService);
  readonly currentUser$ = this.authService.currentUser$;
  readonly equippedItems$ = this.avatarService.getEquippedItems();

  visitedPreview: VisitedAttraction[] = [];
  achievementsPreview: UserAchievement[] = [];
  private visitedPollSub?: Subscription;
  private achievementsPollSub?: Subscription;

  readonly plannedTrips = [
    { name: 'Old Town route', eta: 'Tomorrow', points: 35 },
    { name: 'Island bridges walk', eta: 'In 3 days', points: 25 },
    { name: 'Hidden courtyards', eta: 'Weekend', points: 40 }
  ];

  ngOnInit(): void {
    this.visitedPollSub = timer(0, 15000).pipe(
      switchMap(() => this.attractionService.getVisitedAttractions())
    ).subscribe({
      next: (data) => { this.visitedPreview = data.slice(0, 4); },
      error: () => { this.visitedPreview = []; }
    });
    this.achievementsPollSub = timer(0, 15000).pipe(
      switchMap(() => this.achievementService.getEarnedAchievements())
    ).subscribe({
      next: (data) => { this.achievementsPreview = data.slice(0, 4); },
      error: () => { this.achievementsPreview = []; }
    });
  }

  ngOnDestroy(): void {
    this.visitedPollSub?.unsubscribe();
    this.achievementsPollSub?.unsubscribe();
  }

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
      background: 0,
      base: 10,
      pants: 20,
      shirts: 30,
      mouth: 40,
      eyes: 50,
      hair: 60,
    };

    return [...items].sort((a, b) => {
      const left = slotOrder[a.slot] ?? 100;
      const right = slotOrder[b.slot] ?? 100;
      return left - right;
    });
  }

  getLayerStyle(slot: string): Record<string, string> {
    return { transform: 'translate(0, 0) scale(1)' };
  }
}
