import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';

export interface AgriculturalTaskGateway {
  list(): Observable<AgriculturalTask[]>;
}

export const AGRICULTURAL_TASK_GATEWAY = new InjectionToken<AgriculturalTaskGateway>(
  'AGRICULTURAL_TASK_GATEWAY'
);
