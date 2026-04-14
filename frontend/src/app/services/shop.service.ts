import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { map, Observable, tap } from 'rxjs';
import { AuthService } from './auth.service';
import { AuthUser } from '../models/auth.model';
import { AvatarSkin } from '../models/avatar-skin.model';
import { SkinColor } from '../models/skin-color.model';

@Injectable({
  providedIn: 'root'
})
export class ShopService {
  private readonly http = inject(HttpClient);
  private readonly authService = inject(AuthService);
  private readonly apiUrl = 'http://localhost:8000/api/avatar-skins/';

  getSkins(): Observable<AvatarSkin[]> {
    return this.http.get<AvatarSkin[]>(this.apiUrl);
  }

  getSkinColors(): Observable<SkinColor[]> {
    return this.http.get<SkinColor[]>('http://localhost:8000/api/shop/skins/');
  }

  purchaseSkin(skinId: number): Observable<AuthUser> {
    return this.http.post<{ user: AuthUser }>(`${this.apiUrl}/purchase/`, { skin_id: skinId }).pipe(
      tap((response) => this.authService.updateCurrentUser(response.user)),
      map((response) => response.user)
    );
  }

  selectSkin(skinId: number): Observable<AuthUser> {
    return this.http.post<{ user: AuthUser }>(`${this.apiUrl}/select/`, { skin_id: skinId }).pipe(
      tap((response) => this.authService.updateCurrentUser(response.user)),
      map((response) => response.user)
    );
  }
}
