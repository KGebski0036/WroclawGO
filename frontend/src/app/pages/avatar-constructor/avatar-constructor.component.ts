import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { BehaviorSubject, catchError, combineLatest, map, of, switchMap, tap } from 'rxjs';
import { AvatarItem, UserEquippedAvatarItem } from '../../models/avatar.model';
import { AvatarService } from '../../services/avatar.service';

type ConstructorSection = {
  key: string;
  label: string;
  items: AvatarItem[];
};

@Component({
  selector: 'app-avatar-constructor',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './avatar-constructor.component.html',
  styleUrl: './avatar-constructor.component.css'
})
export class AvatarConstructorComponent {
  readonly avatarService = inject(AvatarService);

  private readonly refresh$ = new BehaviorSubject<void>(void 0);

  equippingItemId: number | null = null;
  removingSlot: string | null = null;
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
        this.avatarService.getUnlockedItems(),
        this.avatarService.getEquippedItems(),
      ])
    ),
    map(([unlockedItems, equippedItems]) => {
      const groupedItems = this.avatarService.groupItemsByTag(unlockedItems);

      const sections: ConstructorSection[] = this.slotConfig.map((slot) => ({
        key: slot.key,
        label: slot.label,
        items: groupedItems[slot.key] ?? [],
      }));

      return {
        sections,
        equippedItems,
        sortedEquippedItems: this.avatarService.getSortedEquippedItems(equippedItems),
      };
    })
  );

  equipItem(item: AvatarItem): void {
    this.errorMessage = '';
    this.successMessage = '';
    this.equippingItemId = item.id;

    this.avatarService.equipItem(item.id).pipe(
      tap(() => {
        this.successMessage = `${item.name} equipped.`;
        this.refresh$.next(void 0);
      }),
      catchError((error) => {
        this.errorMessage = error?.error?.detail || 'Could not equip this item.';
        return of(null);
      })
    ).subscribe({
      complete: () => {
        this.equippingItemId = null;
      }
    });
  }

  removeSlot(slot: string): void {
    this.errorMessage = '';
    this.successMessage = '';
    this.removingSlot = slot;

    this.avatarService.unequipSlot(slot).pipe(
      tap(() => {
        this.successMessage = `${this.getTagLabel(slot)} removed.`;
        this.refresh$.next(void 0);
      }),
      catchError((error) => {
        this.errorMessage = error?.error?.detail || 'Could not remove this item.';
        return of(null);
      })
    ).subscribe({
      complete: () => {
        this.removingSlot = null;
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

  canRemoveSlot(tag: string): boolean {
    return this.avatarService.canUnequipSlot(tag);
  }

  getTagLabel(tag: string): string {
    const labels: Record<string, string> = {
      background: 'Background',
      base: 'Base',
      pants: 'Pants',
      shirts: 'Shirts',
      mouth: 'Mouth',
      eyes: 'Eyes',
      hair: 'Hair',
    };

    return labels[tag] ?? tag;
  }
}
