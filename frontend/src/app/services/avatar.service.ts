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

  getUnlockedItems(): Observable<AvatarItem[]> {
    return this.http
      .get<UserAvatarItem[]>(`${this.apiUrl}/my-items/`)
      .pipe(map((rows) => rows.map((row) => row.item)));
  }

  getEquippedItems(): Observable<UserEquippedAvatarItem[]> {
    return this.http.get<UserEquippedAvatarItem[]>(`${this.apiUrl}/my-equipped/`);
  }

  equipItem(itemId: number): Observable<UserEquippedAvatarItem> {
    return this.http.post<UserEquippedAvatarItem>(`${this.apiUrl}/equip/${itemId}/`, {});
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
}