import { CommonModule } from '@angular/common';
import { Component, inject, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AttractionService } from '../../services/attraction.service';
import { VisitedAttraction } from '../../models/attraction.model';

@Component({
  selector: 'app-visited-attractions',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './visited-attractions.component.html',
  styleUrl: './visited-attractions.component.css'
})
export class VisitedAttractionsComponent implements OnInit {
  private readonly attractionService = inject(AttractionService);

  visited: VisitedAttraction[] = [];
  loading = true;
  errorMessage: string | null = null;

  ngOnInit(): void {
    this.attractionService.getVisitedAttractions().subscribe({
      next: (data) => {
        this.visited = data;
        this.loading = false;
      },
      error: () => {
        this.errorMessage = 'Unable to load visited attractions.';
        this.loading = false;
      }
    });
  }
}
