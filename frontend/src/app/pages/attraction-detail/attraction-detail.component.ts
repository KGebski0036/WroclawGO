import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { map } from 'rxjs';
import { AttractionService } from '../../services/attraction.service';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-attraction-detail',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './attraction-detail.component.html',
  styleUrl: './attraction-detail.component.css'
})
export class AttractionDetailComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly attractionService = inject(AttractionService);
  private readonly authService = inject(AuthService);

  readonly attractionId$ = this.route.paramMap.pipe(
    map((params) => params.get('id') || 'unknown')
  );

  visitMessage: string | null = null;
  visitError: string | null = null;

  markVisited(attractionId: number): void {
    this.visitMessage = null;
    this.visitError = null;

    this.attractionService.visitAttraction(attractionId).subscribe({
      next: () => {
        this.authService.fetchCurrentUser().subscribe();
        this.visitMessage = 'Visit recorded and points added to your profile.';
      },
      error: (error) => {
        this.visitError = error.error?.detail || 'Unable to record visit. Please try again.';
      }
    });
  }
}
