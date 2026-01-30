import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface AgriculturalTaskCreatePayload {
  name: string;
  description?: string | null;
  time_per_sqm?: number | null;
  weather_dependency?: 'low' | 'medium' | 'high' | string;
  required_tools: string[];
  skill_level?: 'beginner' | 'intermediate' | 'advanced' | string;
  region?: string | null;
  task_type?: string | null;
}

export interface AgriculturalTaskGateway {
  list(): Observable<AgriculturalTask[]>;
  show(agriculturalTaskId: number): Observable<AgriculturalTask>;
  create(payload: AgriculturalTaskCreatePayload): Observable<AgriculturalTask>;
  update(agriculturalTaskId: number, payload: AgriculturalTaskCreatePayload): Observable<AgriculturalTask>;
  destroy(agriculturalTaskId: number): Observable<DeletionUndoResponse>;
}

export const AGRICULTURAL_TASK_GATEWAY = new InjectionToken<AgriculturalTaskGateway>(
  'AGRICULTURAL_TASK_GATEWAY'
);
