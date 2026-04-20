import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { BehaviorSubject, catchError, map, of, switchMap, tap } from 'rxjs';
import { AvatarItem, UserEquippedAvatarItem } from '../../models/avatar.model';
import { AvatarService } from '../../services/avatar.service';

@Component({
  selector: 'app-avatar-shop',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './avatar-shop.component.html',
  styleUrl: './avatar-shop.component.css'
})
export class AvatarShopComponent {
  readonly avatarService = inject(AvatarService);

  private readonly refresh$ = new BehaviorSubject<void>(void 0);
  equippingItemId: number | null = null;
  errorMessage = '';

  readonly equippedItems$ = this.refresh$.pipe(
    switchMap(() => this.avatarService.getEquippedItems())
  );

  readonly groupedItems$ = this.refresh$.pipe(
    switchMap(() => this.avatarService.getUnlockedItems()),
    map((items) => this.avatarService.groupItemsByTag(items))
  );

  equipItem(item: AvatarItem): void {
    this.errorMessage = '';
    this.equippingItemId = item.id;

    this.avatarService.equipItem(item.id).pipe(
      tap(() => this.refresh$.next(void 0)),
      catchError(() => {
        this.errorMessage = 'Could not equip this item. Please try again.';
        return of(null);
      })
    ).subscribe({
      complete: () => {
        this.equippingItemId = null;
      }
    });
  }

  isEquipped(item: AvatarItem, equippedItems: UserEquippedAvatarItem[]): boolean {
    return equippedItems.some((equipped) => equipped.item.id === item.id);
  }

  getEquippedItemNameForTag(tag: string, equippedItems: UserEquippedAvatarItem[]): string | null {
    const equipped = equippedItems.find((entry) => entry.slot === tag);
    return equipped ? equipped.item.name : null;
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

  sortTags(a: string, b: string): number {
    return a.localeCompare(b);
  }

  getLayerStyle(slot: string): Record<string, string> {
    const styleBySlot: Record<string, Record<string, string>> = {
      base: { transform: 'translate(0, 0) scale(1)' },
      skin_color: { transform: 'translate(0, 0) scale(1)' },
      hat: { transform: 'translateY(-45%) scale(0.3)' },
      glasses: { transform: 'translateY(-2%) scale(1)' }
    };

    return styleBySlot[slot] ?? { transform: 'translate(0, 0) scale(1)' };
  }
}
