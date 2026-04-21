import { CommonModule } from '@angular/common';
import { Component, inject, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
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
export class AvatarPlaceholderComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly attractionService = inject(AttractionService);
  private readonly achievementService = inject(AchievementService);
  readonly avatarService = inject(AvatarService);

  readonly currentUser$ = this.authService.currentUser$;
  readonly equippedItems$ = this.avatarService.getEquippedItems();

  visitedPreview: VisitedAttraction[] = [];
  achievementsPreview: UserAchievement[] = [];

  ngOnInit(): void {
    this.authService.fetchCurrentUser().subscribe({
      error: () => {}
    });

    this.attractionService.getVisitedAttractions().subscribe({
      next: (data) => { this.visitedPreview = data.slice(0, 4); },
      error: () => { this.visitedPreview = []; }
    });

    this.achievementService.getEarnedAchievements().subscribe({
      next: (data) => { this.achievementsPreview = data.slice(0, 4); },
      error: () => { this.achievementsPreview = []; }
    });
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
    return this.avatarService.getSortedEquippedItems(items);
  }
}
