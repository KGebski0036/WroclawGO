import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AttractionGeoJSON, VisitedAttraction } from '../models/attraction.model';

@Injectable({
  providedIn: 'root'
})
export class AttractionService {
  private apiUrl = 'http://localhost:8000/api/attractions/';
  private visitedUrl = 'http://localhost:8000/api/visited/';

  constructor(private http: HttpClient) { }

  getAttractions(): Observable<AttractionGeoJSON> {
    return this.http.get<AttractionGeoJSON>(this.apiUrl);
  }

  getVisitedAttractions(): Observable<VisitedAttraction[]> {
    return this.http.get<VisitedAttraction[]>(this.visitedUrl);
  }

  markAsVisited(attractionId: number): Observable<VisitedAttraction> {
    return this.http.post<VisitedAttraction>(`${this.visitedUrl}${attractionId}/`, {});
  }

  removeVisited(attractionId: number): Observable<void> {
    return this.http.delete<void>(`${this.visitedUrl}${attractionId}/remove/`);
  }
}