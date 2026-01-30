import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Pesticide } from '../../domain/pesticides/pesticide';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface PesticideCreatePayload {
  name: string;
  active_ingredient: string | null;
  description: string | null;
  crop_id: number;
  pest_id: number;
  region: string | null;
}

export interface PesticideGateway {
  list(): Observable<Pesticide[]>;
  show(pesticideId: number): Observable<Pesticide>;
  create(payload: PesticideCreatePayload): Observable<Pesticide>;
  update(pesticideId: number, payload: PesticideCreatePayload): Observable<Pesticide>;
  destroy(pesticideId: number): Observable<DeletionUndoResponse>;
}

export const PESTICIDE_GATEWAY = new InjectionToken<PesticideGateway>('PESTICIDE_GATEWAY');
