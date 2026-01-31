import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Crop } from '../../domain/crops/crop';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface CropCreatePayload {
  name: string;
  variety: string | null;
  area_per_unit: number | null;
  revenue_per_area: number | null;
  region: string | null;
  groups: string[];
  is_reference?: boolean;
}

export interface CropGateway {
  list(): Observable<Crop[]>;
  show(cropId: number): Observable<Crop>;
  create(payload: CropCreatePayload): Observable<Crop>;
  update(cropId: number, payload: CropCreatePayload): Observable<Crop>;
  destroy(cropId: number): Observable<DeletionUndoResponse>;
}

export const CROP_GATEWAY = new InjectionToken<CropGateway>('CROP_GATEWAY');
