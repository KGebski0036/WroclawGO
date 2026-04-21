import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { map, Observable } from 'rxjs';
import { AvatarItem, UserAvatarItem, UserEquippedAvatarItem } from '../models/avatar.model';

@Injectable({
  providedIn: 'root'
})
export class AvatarService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = 'http://localhost:8000/api/avatar';
  private readonly staticBaseUrl = 'http://localhost:8000/static/';

  getAllItems(): Observable<AvatarItem[]> {
    return this.http.get<AvatarItem[]>(`${this.apiUrl}/items/`);
  }

  getUnlockedItems(): Observable<AvatarItem[]> {
    return this.http
      .get<UserAvatarItem[]>(`${this.apiUrl}/my-items/`)
      .pipe(map((rows) => rows.map((row) => row.item)));
  }

  getEquippedItems(): Observable<UserEquippedAvatarItem[]> {
    return this.http.get<UserEquippedAvatarItem[]>(`${this.apiUrl}/my-equipped/`);
  }

  purchaseItem(itemId: number): Observable<UserAvatarItem> {
    return this.http.post<UserAvatarItem>(`${this.apiUrl}/purchase/${itemId}/`, {});
  }

  equipItem(itemId: number): Observable<UserEquippedAvatarItem> {
    return this.http.post<UserEquippedAvatarItem>(`${this.apiUrl}/equip/${itemId}/`, {});
  }

  unequipSlot(slot: string): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/unequip/${slot}/`);
  }

  toStaticUrl(svgPath: string): string {
    if (svgPath.startsWith('http://') || svgPath.startsWith('https://')) {
      return svgPath;
    }

    const normalizedPath = svgPath.startsWith('/') ? svgPath.slice(1) : svgPath;
    return `${this.staticBaseUrl}${normalizedPath}`;
  }

  groupItemsByTag(items: AvatarItem[]): Record<string, AvatarItem[]> {
    return items.reduce<Record<string, AvatarItem[]>>((acc, item) => {
      if (!acc[item.tag]) {
        acc[item.tag] = [];
      }
      acc[item.tag].push(item);
      return acc;
    }, {});
  }

  getSlotOrder(slot: string): number {
    const slotOrder: Record<string, number> = {
      background: 0,
      base: 10,
      pants: 20,
      shirts: 30,
      mouth: 40,
      eyes: 50,
      hair: 60,
    };

    return slotOrder[slot] ?? 100;
  }

  canUnequipSlot(slot: string): boolean {
    return !['base', 'background'].includes(slot);
  }

  getSortedEquippedItems(items: UserEquippedAvatarItem[]): UserEquippedAvatarItem[] {
    return [...items].sort((a, b) => this.getSlotOrder(a.slot) - this.getSlotOrder(b.slot));
  }
}
