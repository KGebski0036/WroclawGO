import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { VisitedAttraction } from '../../models/attraction.model';
import { AttractionService } from '../../services/attraction.service';

@Component({
  selector: 'app-visited-attractions',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './visited-attractions.component.html',
  styleUrl: './visited-attractions.component.css'
})
export class VisitedAttractionsComponent implements OnInit {
  visitedAttractions: VisitedAttraction[] = [];
  loading = true;
  error: string | null = null;

  constructor(private attractionService: AttractionService) {}

  ngOnInit(): void {
    this.attractionService.getVisitedAttractions().subscribe({
      next: (data) => {
        this.visitedAttractions = data;
        this.loading = false;
      },
      error: () => {
        this.error = 'Failed to load visited attractions.';
        this.loading = false;
      }
    });
  }
}
