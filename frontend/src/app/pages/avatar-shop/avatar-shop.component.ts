import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { BehaviorSubject, catchError, combineLatest, map, of, switchMap, tap } from 'rxjs';
import { AvatarItem } from '../../models/avatar.model';
import { AuthService } from '../../services/auth.service';
import { AvatarService } from '../../services/avatar.service';

type ShopSection = {
  key: string;
  label: string;
  items: AvatarItem[];
};

@Component({
  selector: 'app-avatar-shop',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './avatar-shop.component.html',
  styleUrl: './avatar-shop.component.css'
})
export class AvatarShopComponent {
  readonly avatarService = inject(AvatarService);
  private readonly authService = inject(AuthService);

  private readonly refresh$ = new BehaviorSubject<void>(void 0);

  purchasingItemId: number | null = null;
  errorMessage = '';
  successMessage = '';

  private readonly slotConfig = [
    { key: 'background', label: 'Background' },
    { key: 'base', label: 'Base' },
    { key: 'pants', label: 'Pants' },
    { key: 'shirts', label: 'Shirts' },
    { key: 'mouth', label: 'Mouth' },
    { key: 'eyes', label: 'Eyes' },
    { key: 'hair', label: 'Hair' },
  ];

  readonly vm$ = this.refresh$.pipe(
    switchMap(() =>
      combineLatest([
        this.avatarService.getAllItems(),
        this.avatarService.getUnlockedItems(),
        this.authService.fetchCurrentUser(),
      ])
    ),
    map(([allItems, unlockedItems, currentUser]) => {
      const groupedAllItems = this.avatarService.groupItemsByTag(allItems);
      const ownedIds = new Set(unlockedItems.map((item) => item.id));

      const sections: ShopSection[] = this.slotConfig.map((slot) => ({
        key: slot.key,
        label: slot.label,
        items: groupedAllItems[slot.key] ?? [],
      }));

      return {
        sections,
        ownedIds,
        currentUser,
      };
    })
  );

  buyItem(item: AvatarItem): void {
    this.errorMessage = '';
    this.successMessage = '';
    this.purchasingItemId = item.id;

    this.avatarService.purchaseItem(item.id).pipe(
      switchMap(() => this.authService.fetchCurrentUser()),
      tap(() => {
        this.successMessage = `${item.name} has been added to your constructor.`;
        this.refresh$.next(void 0);
      }),
      catchError((error) => {
        this.errorMessage = error?.error?.detail || 'Could not buy this item.';
        return of(null);
      })
    ).subscribe({
      complete: () => {
        this.purchasingItemId = null;
      }
    });
  }

  isOwned(itemId: number, ownedIds: Set<number>): boolean {
    return ownedIds.has(itemId);
  }

  canBuy(item: AvatarItem, points: number, ownedIds: Set<number>): boolean {
    return !ownedIds.has(item.id) && points >= item.cost;
  }

  getButtonLabel(item: AvatarItem, points: number, ownedIds: Set<number>): string {
    if (ownedIds.has(item.id)) {
      return 'Owned';
    }

    if (points < item.cost) {
      return 'Not enough points';
    }

    return 'Buy';
  }
}
