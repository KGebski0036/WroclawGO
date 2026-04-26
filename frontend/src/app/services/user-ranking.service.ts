import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { API_URL } from '../config/api.config';
import { FavoriteToggleResponse, LeaderboardResponse, PublicUserProfile } from '../models/user-ranking.model';

@Injectable({
  providedIn: 'root'
})
export class UserRankingService {
  private readonly baseUrl = `${API_URL}/users`;

  constructor(private readonly http: HttpClient) {}

  getLeaderboard(page: number, pageSize: number, search: string, likedOnly: boolean): Observable<LeaderboardResponse> {
    let params = new HttpParams()
      .set('page', String(page))
      .set('page_size', String(pageSize))
      .set('search', search.trim());

    if (likedOnly) {
      params = params.set('liked_only', '1');
    }

    return this.http.get<LeaderboardResponse>(`${this.baseUrl}/ranking/`, { params });
  }

  getPublicProfile(username: string): Observable<PublicUserProfile> {
    return this.http.get<PublicUserProfile>(`${this.baseUrl}/${encodeURIComponent(username)}/`);
  }

  toggleFavorite(username: string): Observable<FavoriteToggleResponse> {
    return this.http.post<FavoriteToggleResponse>(
      `${this.baseUrl}/${encodeURIComponent(username)}/favorite/`,
      {}
    );
  }
}
