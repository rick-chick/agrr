import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Farm } from '../../domain/farms/farm';
import { Field } from '../../domain/farms/field';

export interface FarmCreatePayload {
  name: string;
  region: string;
  latitude: number;
  longitude: number;
}

export interface FarmGateway {
  list(): Observable<Farm[]>;
  show(farmId: number): Observable<Farm>;
  listFieldsByFarm(farmId: number): Observable<Field[]>;
  create(payload: FarmCreatePayload): Observable<Farm>;
  update(farmId: number, payload: FarmCreatePayload): Observable<Farm>;
  destroy(farmId: number): Observable<void>;
}

export const FARM_GATEWAY = new InjectionToken<FarmGateway>('FARM_GATEWAY');
