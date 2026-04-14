import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Router } from '@angular/router';
import { BehaviorSubject, catchError, map, Observable, of, tap, throwError } from 'rxjs';
import { AuthResponse, AuthUser, LoginRequest, RegisterRequest } from '../models/auth.model';
import { SkinColor } from '../models/skin-color.model';

const DEFAULT_SKIN_NAME = 'Golden Aura';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
  private readonly apiUrl = 'http://localhost:8000/api/auth';
  private readonly accessTokenKey = 'wroclawgo.access';
  private readonly refreshTokenKey = 'wroclawgo.refresh';
  private readonly userSubject = new BehaviorSubject<AuthUser | null>(null);

  readonly currentUser$ = this.userSubject.asObservable();
  readonly activeSkin$ = this.currentUser$.pipe(map((user) => this.getActiveSkinFromUser(user)));

  initializeAuth(): void {
    if (!this.getAccessToken()) {
      this.userSubject.next(null);
      return;
    }

    this.fetchCurrentUser().subscribe({
      error: () => this.clearSession()
    });
  }

  register(payload: RegisterRequest): Observable<AuthUser> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/register/`, payload).pipe(
      tap((response) => this.setSession(response)),
      map((response) => response.user)
    );
  }

  login(payload: LoginRequest): Observable<AuthUser> {
    return this.http.post<AuthResponse>(`${this.apiUrl}/login/`, payload).pipe(
      tap((response) => this.setSession(response)),
      map((response) => response.user)
    );
  }

  logout(): Observable<void> {
    const refresh = this.getRefreshToken();

    if (!refresh) {
      this.clearSession();
      return of(void 0);
    }

    return this.http.post<void>(`${this.apiUrl}/logout/`, { refresh }).pipe(
      tap(() => this.clearSession()),
      catchError(() => {
        this.clearSession();
        return of(void 0);
      })
    );
  }

  fetchCurrentUser(): Observable<AuthUser> {
    return this.http.get<AuthUser>(`${this.apiUrl}/me/`).pipe(
      tap((user) => this.userSubject.next(this.normalizeUserSkins(user)))
    );
  }

  refreshAccessToken(): Observable<string> {
    const refresh = this.getRefreshToken();

    if (!refresh) {
      return throwError(() => new Error('Missing refresh token.'));
    }

    return this.http.post<{ access: string }>(`${this.apiUrl}/token/refresh/`, { refresh }).pipe(
      tap((response) => localStorage.setItem(this.accessTokenKey, response.access)),
      map((response) => response.access)
    );
  }

  getAccessToken(): string | null {
    return localStorage.getItem(this.accessTokenKey);
  }

  getRefreshToken(): string | null {
    return localStorage.getItem(this.refreshTokenKey);
  }

  isAuthenticated(): boolean {
    return this.userSubject.value !== null || this.getAccessToken() !== null;
  }

  getCurrentUserSnapshot(): AuthUser | null {
    return this.userSubject.value;
  }

  updateCurrentUser(user: AuthUser): void {
    this.userSubject.next(this.normalizeUserSkins(user));
  }

  private normalizeUserSkins(user: AuthUser): AuthUser {
    const defaultSkin: SkinColor = {
      id: -1,
      name: DEFAULT_SKIN_NAME,
      color_value: '#f7d455',
      price: 0,
      image_file_name: 'golden-aura.png'
    };

    const ownedSkins = [...user.owned_skins];
    const ownedSkinNames = new Set(ownedSkins.map((skin) => skin.name));
    const ownedSkinIds = new Set(ownedSkins.map((skin) => skin.id));

    if (!ownedSkinNames.has(DEFAULT_SKIN_NAME)) {
      ownedSkins.push(defaultSkin);
      ownedSkinNames.add(DEFAULT_SKIN_NAME);
      ownedSkinIds.add(defaultSkin.id);
    }

    let selectedSkin = user.selected_skin;

    if (!selectedSkin) {
      selectedSkin = ownedSkins.find((skin) => skin.name === DEFAULT_SKIN_NAME) ?? defaultSkin;
    }

    if (selectedSkin && !ownedSkinIds.has(selectedSkin.id)) {
      ownedSkins.push(selectedSkin);
    }

    return {
      ...user,
      owned_skins: ownedSkins,
      selected_skin: selectedSkin as any
    };
  }

  private getActiveSkinFromUser(user: AuthUser | null): AuthUser['selected_skin'] | null {
    if (!user) {
      return null;
    }

    if (user.selected_skin) {
      return user.selected_skin;
    }

    const defaultSkin = user.owned_skins.find((skin) => skin.name === DEFAULT_SKIN_NAME);
    return defaultSkin ?? null;
  }

  clearSession(): void {
    localStorage.removeItem(this.accessTokenKey);
    localStorage.removeItem(this.refreshTokenKey);
    this.userSubject.next(null);
  }

  redirectToLogin(): void {
    this.router.navigate(['/login']);
  }

  private setSession(response: AuthResponse): void {
    localStorage.setItem(this.accessTokenKey, response.access);
    localStorage.setItem(this.refreshTokenKey, response.refresh);
    this.userSubject.next(this.normalizeUserSkins(response.user));
  }
}