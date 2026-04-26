import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Achievement, UserAchievement } from '../models/achievement.model';
import { API_URL } from '../config/api.config';

@Injectable({
  providedIn: 'root'
})
export class AchievementService {
  private readonly baseUrl = `${API_URL}/achievements`;

  constructor(private http: HttpClient) {}

  getAllAchievements(): Observable<Achievement[]> {
    return this.http.get<Achievement[]>(`${this.baseUrl}/`);
  }

  getEarnedAchievements(): Observable<UserAchievement[]> {
    return this.http.get<UserAchievement[]>(`${this.baseUrl}/my/`);
  }
}
