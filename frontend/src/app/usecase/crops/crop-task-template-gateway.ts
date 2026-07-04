import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersCropTaskTemplate } from '../../domain/crops/masters-crop-task-template';

export interface CropTaskTemplateCreatePayload {
  agricultural_task_id: number;
}

export interface CropTaskTemplateGateway {
  list(cropId: number): Observable<MastersCropTaskTemplate[]>;
  create(cropId: number, payload: CropTaskTemplateCreatePayload): Observable<MastersCropTaskTemplate>;
  destroy(cropId: number, templateId: number): Observable<void>;
}

export const CROP_TASK_TEMPLATE_GATEWAY = new InjectionToken<CropTaskTemplateGateway>(
  'CROP_TASK_TEMPLATE_GATEWAY'
);
