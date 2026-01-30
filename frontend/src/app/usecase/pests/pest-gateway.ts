import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Pest } from '../../domain/pests/pest';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface PestCreatePayload {
  name: string;
  name_scientific: string | null;
  family: string | null;
  order: string | null;
  description: string | null;
  occurrence_season: string | null;
  region: string | null;
}

export interface PestGateway {
  list(): Observable<Pest[]>;
  show(pestId: number): Observable<Pest>;
  create(payload: PestCreatePayload): Observable<Pest>;
  update(pestId: number, payload: PestCreatePayload): Observable<Pest>;
  destroy(pestId: number): Observable<DeletionUndoResponse>;
}

export const PEST_GATEWAY = new InjectionToken<PestGateway>('PEST_GATEWAY');
