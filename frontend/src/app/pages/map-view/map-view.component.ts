import { CommonModule } from '@angular/common';
import { AfterViewInit, Component, ElementRef, OnDestroy, ViewChild } from '@angular/core';
import * as maplibregl from 'maplibre-gl';
import { AttractionService } from '../../services/attraction.service';

@Component({
  selector: 'app-map-view',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './map-view.component.html',
  styleUrl: './map-view.component.css'
})
export class MapViewComponent implements AfterViewInit, OnDestroy {
  @ViewChild('mapContainer', { static: true }) mapContainer!: ElementRef<HTMLDivElement>;

  private map?: maplibregl.Map;

  private readonly categoryMap: Record<string, string> = {
    Muzeum: 'blue',
    Park: 'green',
    Krasnal: 'orange',
    Kościół: 'pink',
    Zabytki: 'purple'
  };

  constructor(private attractionService: AttractionService) {}

  private getPopupDetailsLink(featureId: number | undefined): string {
    return '';
    //return `<a href="/attraction/${featureId}" style="display: inline-block; margin-top: 10px; color: #0f5d8c; font-weight: 700; text-decoration: none;">View details</a>`;
  }

  ngAfterViewInit(): void {
    this.initMap();
  }

  ngOnDestroy(): void {
    this.map?.remove();
  }

  private initMap(): void {
    this.map = new maplibregl.Map({
      container: this.mapContainer.nativeElement,
      style: 'https://tiles.openfreemap.org/styles/liberty',
      center: [17.0385, 51.1079],
      zoom: 13
    });

    this.map.on('load', () => this.loadAttractions());
  }

  private loadAttractions(): void {
    this.attractionService.getAttractions().subscribe({
      next: (data) => {
        data.features.forEach((feature) => {
          const coords = feature.geometry?.coordinates;
          if (!coords || coords[0] == null || coords[1] == null) {
            console.warn('Pominięto punkt bez koordynatów:', feature);
            return;
          }

          const name = feature.properties?.name || 'Brak nazwy';
          const description = feature.properties?.description || 'Brak opisu';
          const category = feature.properties?.category;
          const attractionId = feature.properties?.id;

          const markerColor = this.categoryMap[category] || '#f43f5e';

          const popup = new maplibregl.Popup({ offset: 25 }).setHTML(`
            <div style="color: #111827;">
              <h3 style="margin: 0; font-size: 1rem;">${name}</h3>
              <p style="margin: 6px 0 0;">${description}</p>
            </div>
          `);

          new maplibregl.Marker({ color: markerColor })
            .setLngLat([coords[0], coords[1]])
            .setPopup(popup)
            .addTo(this.map!);
        });
      },
      error: (err) => console.error('Błąd API:', err)
    });
  }
}
