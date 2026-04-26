import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Router } from '@angular/router';
import { BehaviorSubject, catchError, map, Observable, of, tap, throwError } from 'rxjs';
import { AuthResponse, AuthUser, LoginRequest, RegisterRequest } from '../models/auth.model';
import { API_URL } from '../config/api.config';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
  private readonly apiUrl = `${API_URL}/auth`;
  private readonly accessTokenKey = 'wroclawgo.access';
  private readonly refreshTokenKey = 'wroclawgo.refresh';
  private readonly userSubject = new BehaviorSubject<AuthUser | null>(null);

  readonly currentUser$ = this.userSubject.asObservable();

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
      tap((user) => this.userSubject.next(user))
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
    this.userSubject.next(response.user);
  }
}