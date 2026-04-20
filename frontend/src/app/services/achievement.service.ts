import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Achievement, UserAchievement } from '../models/achievement.model';

@Injectable({
  providedIn: 'root'
})
export class AchievementService {
  private readonly baseUrl = 'http://localhost:8000/api/achievements';

  constructor(private http: HttpClient) {}

  getAllAchievements(): Observable<Achievement[]> {
    return this.http.get<Achievement[]>(`${this.baseUrl}/`);
  }

  getEarnedAchievements(): Observable<UserAchievement[]> {
    return this.http.get<UserAchievement[]>(`${this.baseUrl}/my/`);
  }
}
