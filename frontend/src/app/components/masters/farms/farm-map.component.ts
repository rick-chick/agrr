import { Component, Input, OnChanges, SimpleChanges } from '@angular/core';
import { LeafletModule } from '@bluehalo/ngx-leaflet';
import { LatLngExpression, tileLayer, marker, Marker } from 'leaflet';

@Component({
  selector: 'app-farm-map',
  standalone: true,
  imports: [LeafletModule],
  template: `
    <div
      class="map"
      leaflet
      [leafletOptions]="options"
      [leafletLayers]="layers"
    ></div>
  `,
  styleUrl: './farm-map.component.css'
})
export class FarmMapComponent implements OnChanges {
  @Input() latitude = 35.6895;
  @Input() longitude = 139.6917;
  @Input() name = 'Farm';

  options = {
    layers: [
      tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '© OpenStreetMap'
      })
    ],
    zoom: 13,
    center: [this.latitude, this.longitude] as LatLngExpression
  };

  layers: Marker[] = [];

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['latitude'] || changes['longitude']) {
      const center: LatLngExpression = [this.latitude, this.longitude];
      this.options = { ...this.options, center };
      this.layers = [
        marker(center).bindPopup(this.name)
      ];
    }
  }
}
