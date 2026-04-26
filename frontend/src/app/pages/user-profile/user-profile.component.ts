import { CommonModule } from '@angular/common';
import { Component, inject, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { Subscription, timer } from 'rxjs';
import { switchMap } from 'rxjs/operators';
import { UserEquippedAvatarItem } from '../../models/avatar.model';
import { PublicUserProfile } from '../../models/user-ranking.model';
import { AvatarService } from '../../services/avatar.service';
import { AuthService } from '../../services/auth.service';
import { UserRankingService } from '../../services/user-ranking.service';

@Component({
  selector: 'app-user-profile',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './user-profile.component.html',
  styleUrl: './user-profile.component.css'
})
export class UserProfileComponent implements OnInit, OnDestroy {
  readonly avatarService = inject(AvatarService);
  private readonly route = inject(ActivatedRoute);
  private readonly rankingService = inject(UserRankingService);
  private readonly authService = inject(AuthService);

  profile: PublicUserProfile | null = null;
  loading = true;
  error: string | null = null;
  likePending = false;
  readonly currentUsername = this.authService.getCurrentUserSnapshot()?.username || '';

  private readonly subscriptions = new Subscription();

  ngOnInit(): void {
    const pollSub = this.route.paramMap
      .pipe(
        switchMap((params) => {
          const username = params.get('username') || '';
          this.loading = true;
          return timer(0, 15000).pipe(
            switchMap(() => this.rankingService.getPublicProfile(username))
          );
        })
      )
      .subscribe({
        next: (profile) => {
          this.profile = profile;
          this.loading = false;
          this.error = null;
        },
        error: () => {
          this.error = 'Failed to load user profile.';
          this.loading = false;
        }
      });

    this.subscriptions.add(pollSub);
  }

  ngOnDestroy(): void {
    this.subscriptions.unsubscribe();
  }

  getOrderedEquippedItems(items: UserEquippedAvatarItem[]): UserEquippedAvatarItem[] {
    return this.avatarService.getSortedEquippedItems(items);
  }

  get isSelfProfile(): boolean {
    if (!this.profile || !this.currentUsername) {
      return false;
    }

    return this.profile.username.toLowerCase() === this.currentUsername.toLowerCase();
  }

  toggleFavorite(): void {
    if (!this.profile || this.likePending || this.isSelfProfile) {
      return;
    }

    this.likePending = true;
    this.rankingService.toggleFavorite(this.profile.username).subscribe({
      next: (response) => {
        if (!this.profile) {
          return;
        }

        this.profile.is_liked = response.is_liked;
        this.profile.favorites_count = response.favorites_count;
      },
      error: () => {
        this.error = 'Could not update favorites right now.';
      },
      complete: () => {
        this.likePending = false;
      }
    });
  }
}
