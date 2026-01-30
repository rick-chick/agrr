import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Fertilize } from '../../domain/fertilizes/fertilize';

export interface FertilizeCreatePayload {
  name: string;
  n: number | null;
  p: number | null;
  k: number | null;
  description: string | null;
  package_size: number | null;
  region: string | null;
}

export interface FertilizeGateway {
  list(): Observable<Fertilize[]>;
  show(fertilizeId: number): Observable<Fertilize>;
  create(payload: FertilizeCreatePayload): Observable<Fertilize>;
  update(fertilizeId: number, payload: FertilizeCreatePayload): Observable<Fertilize>;
  destroy(fertilizeId: number): Observable<void>;
}

export const FERTILIZE_GATEWAY = new InjectionToken<FertilizeGateway>('FERTILIZE_GATEWAY');
