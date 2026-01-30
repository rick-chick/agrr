import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Pest } from '../../domain/pests/pest';

export interface PestGateway {
  list(): Observable<Pest[]>;
}

export const PEST_GATEWAY = new InjectionToken<PestGateway>('PEST_GATEWAY');
