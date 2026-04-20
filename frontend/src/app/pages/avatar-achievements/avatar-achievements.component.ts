import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { Achievement, UserAchievement } from '../../models/achievement.model';
import { AchievementService } from '../../services/achievement.service';

@Component({
  selector: 'app-avatar-achievements',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './avatar-achievements.component.html',
  styleUrl: './avatar-achievements.component.css'
})
export class AvatarAchievementsComponent implements OnInit {
  allAchievements: Achievement[] = [];
  earnedIds = new Set<number>();
  earnedMap = new Map<number, UserAchievement>();
  loading = true;
  error: string | null = null;

  constructor(private achievementService: AchievementService) {}

  ngOnInit(): void {
    this.achievementService.getAllAchievements().subscribe({
      next: (all) => {
        this.allAchievements = all;
        this.achievementService.getEarnedAchievements().subscribe({
          next: (earned) => {
            earned.forEach(ua => {
              this.earnedIds.add(ua.achievement.id);
              this.earnedMap.set(ua.achievement.id, ua);
            });
            this.loading = false;
          },
          error: () => { this.error = 'Failed to load earned achievements.'; this.loading = false; }
        });
      },
      error: () => { this.error = 'Failed to load achievements.'; this.loading = false; }
    });
  }

  isEarned(id: number): boolean {
    return this.earnedIds.has(id);
  }

  earnedDate(id: number): string | null {
    return this.earnedMap.get(id)?.earned_at ?? null;
  }
}
