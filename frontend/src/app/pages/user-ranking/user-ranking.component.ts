import { CommonModule } from '@angular/common';
import { Component, inject, OnDestroy, OnInit } from '@angular/core';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Subscription, timer } from 'rxjs';
import { debounceTime, distinctUntilChanged, switchMap } from 'rxjs/operators';
import { UserEquippedAvatarItem } from '../../models/avatar.model';
import { LeaderboardResponse, LeaderboardUser } from '../../models/user-ranking.model';
import { AvatarService } from '../../services/avatar.service';
import { AuthService } from '../../services/auth.service';
import { UserRankingService } from '../../services/user-ranking.service';

@Component({
  selector: 'app-user-ranking',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './user-ranking.component.html',
  styleUrl: './user-ranking.component.css'
})
export class UserRankingComponent implements OnInit, OnDestroy {
  private readonly rankingService = inject(UserRankingService);
  private readonly authService = inject(AuthService);
  readonly avatarService = inject(AvatarService);

  readonly searchControl = new FormControl('', { nonNullable: true });
  readonly modeControl = new FormControl<'all' | 'liked'>('all', { nonNullable: true });

  users: LeaderboardUser[] = [];
  loading = true;
  error: string | null = null;
  totalUsers = 0;
  currentPage = 1;
  readonly pageSize = 20;
  readonly currentUsername = this.authService.getCurrentUserSnapshot()?.username || '';
  private readonly pendingLikes = new Set<number>();

  private readonly subscriptions = new Subscription();

  ngOnInit(): void {
    this.startPolling();

    const searchSub = this.searchControl.valueChanges
      .pipe(debounceTime(250), distinctUntilChanged())
      .subscribe(() => {
        this.currentPage = 1;
        this.fetchPage();
      });

    const modeSub = this.modeControl.valueChanges
      .pipe(distinctUntilChanged())
      .subscribe(() => {
        this.currentPage = 1;
        this.fetchPage();
      });

    this.subscriptions.add(searchSub);
    this.subscriptions.add(modeSub);
  }

  ngOnDestroy(): void {
    this.subscriptions.unsubscribe();
  }

  get totalPages(): number {
    return Math.max(1, Math.ceil(this.totalUsers / this.pageSize));
  }

  get canGoPrev(): boolean {
    return this.currentPage > 1;
  }

  get canGoNext(): boolean {
    return this.currentPage < this.totalPages;
  }

  goToPrev(): void {
    if (!this.canGoPrev) {
      return;
    }

    this.currentPage -= 1;
    this.fetchPage();
  }

  goToNext(): void {
    if (!this.canGoNext) {
      return;
    }

    this.currentPage += 1;
    this.fetchPage();
  }

  getOrderedEquippedItems(items: UserEquippedAvatarItem[]): UserEquippedAvatarItem[] {
    return this.avatarService.getSortedEquippedItems(items);
  }

  isSelf(user: LeaderboardUser): boolean {
    return !!this.currentUsername && user.username.toLowerCase() === this.currentUsername.toLowerCase();
  }

  isLikePending(user: LeaderboardUser): boolean {
    return this.pendingLikes.has(user.id);
  }

  toggleFavorite(user: LeaderboardUser, event: Event): void {
    event.preventDefault();
    event.stopPropagation();

    if (this.isSelf(user) || this.isLikePending(user)) {
      return;
    }

    this.pendingLikes.add(user.id);
    this.rankingService.toggleFavorite(user.username).subscribe({
      next: (response) => {
        user.is_liked = response.is_liked;
        user.favorites_count = response.favorites_count;

        if (this.modeControl.value === 'liked' && !response.is_liked) {
          this.fetchPage();
          return;
        }
      },
      error: () => {
        this.error = 'Could not update favorites right now.';
      },
      complete: () => {
        this.pendingLikes.delete(user.id);
      }
    });
  }

  get isLikedMode(): boolean {
    return this.modeControl.value === 'liked';
  }

  private startPolling(): void {
    const pollSub = timer(0, 15000)
      .pipe(
        switchMap(() =>
          this.rankingService.getLeaderboard(
            this.currentPage,
            this.pageSize,
            this.searchControl.value,
            this.modeControl.value === 'liked'
          )
        )
      )
      .subscribe({
        next: (response) => this.applyLeaderboard(response),
        error: () => {
          this.error = 'Failed to load leaderboard.';
          this.loading = false;
        }
      });

    this.subscriptions.add(pollSub);
  }

  private fetchPage(): void {
    this.loading = true;
    this.rankingService.getLeaderboard(
      this.currentPage,
      this.pageSize,
      this.searchControl.value,
      this.modeControl.value === 'liked'
    ).subscribe({
      next: (response) => this.applyLeaderboard(response),
      error: () => {
        this.error = 'Failed to load leaderboard.';
        this.loading = false;
      }
    });
  }

  private applyLeaderboard(response: LeaderboardResponse): void {
    this.users = response.results;
    this.totalUsers = response.count;
    this.loading = false;
    this.error = null;

    if (this.currentPage > this.totalPages) {
      this.currentPage = this.totalPages;
      this.fetchPage();
    }
  }
}
