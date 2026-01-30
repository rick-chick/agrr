import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { Pesticide } from '../../domain/pesticides/pesticide';

export interface PesticideGateway {
  list(): Observable<Pesticide[]>;
}

export const PESTICIDE_GATEWAY = new InjectionToken<PesticideGateway>('PESTICIDE_GATEWAY');
