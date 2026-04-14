import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AttractionGeoJSON, VisitedAttraction } from '../models/attraction.model';
import { AuthUser } from '../models/auth.model';

@Injectable({
  providedIn: 'root'
})
export class AttractionService {
  private apiUrl = 'http://localhost:8000/api/attractions/';

  constructor(private http: HttpClient) { }

  getAttractions(): Observable<AttractionGeoJSON> {
    return this.http.get<AttractionGeoJSON>(this.apiUrl);
  }

  visitAttraction(attractionId: number): Observable<AuthUser> {
    return this.http.post<AuthUser>(`${this.apiUrl}${attractionId}/visit/`, {});
  }

  getVisitedAttractions(): Observable<VisitedAttraction[]> {
    return this.http.get<VisitedAttraction[]>(`${this.apiUrl}visited/`);
  }
}
