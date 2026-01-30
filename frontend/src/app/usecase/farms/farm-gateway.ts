import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Farm } from '../../domain/farms/farm';
import { Field } from '../../domain/farms/field';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface FarmCreatePayload {
  name: string;
  region: string;
  latitude: number;
  longitude: number;
}

export interface FieldCreatePayload {
  name: string;
  area: number | null;
  daily_fixed_cost: number | null;
  region: string | null;
}

export interface FarmGateway {
  list(): Observable<Farm[]>;
  show(farmId: number): Observable<Farm>;
  listFieldsByFarm(farmId: number): Observable<Field[]>;
  create(payload: FarmCreatePayload): Observable<Farm>;
  update(farmId: number, payload: FarmCreatePayload): Observable<Farm>;
  destroy(farmId: number): Observable<DeletionUndoResponse>;
  createField(farmId: number, payload: FieldCreatePayload): Observable<Field>;
  updateField(fieldId: number, payload: FieldCreatePayload): Observable<Field>;
  destroyField(fieldId: number): Observable<DeletionUndoResponse>;
}

export const FARM_GATEWAY = new InjectionToken<FarmGateway>('FARM_GATEWAY');
