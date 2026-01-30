import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Crop } from '../../domain/crops/crop';

export interface CropGateway {
  list(): Observable<Crop[]>;
  show(cropId: number): Observable<Crop>;
}

export const CROP_GATEWAY = new InjectionToken<CropGateway>('CROP_GATEWAY');
