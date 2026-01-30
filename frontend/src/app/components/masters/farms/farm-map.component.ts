import {
  Component,
  Input,
  Output,
  EventEmitter,
  OnChanges,
  SimpleChanges,
  NgZone,
  inject
} from '@angular/core';
import { LeafletModule } from '@bluehalo/ngx-leaflet';
import { LatLngExpression, tileLayer, marker, Marker, Map } from 'leaflet';

const DEFAULT_LAT = 35.6812;
const DEFAULT_LNG = 139.7671;

function isValidCoord(lat: number, lng: number): boolean {
  return (
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180 &&
    !Number.isNaN(lat) &&
    !Number.isNaN(lng)
  );
}

@Component({
  selector: 'app-farm-map',
  standalone: true,
  imports: [LeafletModule],
  template: `
    <div
      class="map"
      leaflet
      [leafletOptions]="options"
      [leafletLayers]="displayLayers"
      (leafletMapReady)="onMapReady($event)"
      (leafletClick)="onMapClick($event)"
    ></div>
  `,
  styleUrl: './farm-map.component.css'
})
export class FarmMapComponent implements OnChanges {
  @Input() latitude: number = DEFAULT_LAT;
  @Input() longitude: number = DEFAULT_LNG;
  @Input() name = 'Farm';
  @Input() editable = false;

  @Output() coordinatesChange = new EventEmitter<{
    latitude: number;
    longitude: number;
  }>();

  private readonly zone = inject(NgZone);

  private map: Map | null = null;
  private editableMarker: Marker | null = null;

  private get effectiveLat(): number {
    return isValidCoord(this.latitude, this.longitude)
      ? this.latitude
      : DEFAULT_LAT;
  }

  private get effectiveLng(): number {
    return isValidCoord(this.latitude, this.longitude)
      ? this.longitude
      : DEFAULT_LNG;
  }

  get options(): {
    layers: ReturnType<typeof tileLayer>[];
    zoom: number;
    center: LatLngExpression;
  } {
    return {
      layers: [
        tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          maxZoom: 19,
          attribution: '© OpenStreetMap'
        })
      ],
      zoom: 13,
      center: [this.effectiveLat, this.effectiveLng] as LatLngExpression
    };
  }

  displayLayers: Marker[] = [];

  ngOnChanges(changes: SimpleChanges): void {
    const latChange = changes['latitude'];
    const lngChange = changes['longitude'];
    if (latChange || lngChange) {
      const center: LatLngExpression = [this.effectiveLat, this.effectiveLng];
      if (this.editable) {
        if (this.editableMarker) {
          this.editableMarker.setLatLng(center);
          if (this.map) {
            this.map.setView(center, this.map.getZoom());
          }
        }
        this.displayLayers = [];
      } else {
        this.displayLayers = [marker(center).bindPopup(this.name)];
      }
    }
  }

  onMapReady(map: Map): void {
    if (!this.editable) return;
    this.map = map;
    const center: LatLngExpression = [this.effectiveLat, this.effectiveLng];
    const m = marker(center, { draggable: true }).addTo(map);
    m.bindPopup(this.name);
    m.on('dragend', () => {
      const latLng = m.getLatLng();
      this.zone.run(() => {
        this.coordinatesChange.emit({
          latitude: latLng.lat,
          longitude: latLng.lng
        });
      });
    });
    this.editableMarker = m;
  }

  onMapClick(event: { latlng: { lat: number; lng: number } }): void {
    if (!this.editable || !this.editableMarker) return;
    const { lat, lng } = event.latlng;
    this.editableMarker.setLatLng([lat, lng]);
    this.zone.run(() => {
      this.coordinatesChange.emit({ latitude: lat, longitude: lng });
    });
  }
}
