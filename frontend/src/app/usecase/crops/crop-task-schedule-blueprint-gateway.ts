import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';

export interface CropTaskScheduleBlueprintCreatePayload {
  agricultural_task_id: number;
  stage_order: number;
  stage_name?: string | null;
  gdd_trigger: number;
  task_type?: string;
  description?: string | null;
  priority?: number;
}

export interface CropTaskScheduleBlueprintUpdatePayload {
  gdd_trigger: number;
}

export interface CropTaskScheduleBlueprintGateway {
  list(cropId: number): Observable<CropTaskScheduleBlueprint[]>;
  create(
    cropId: number,
    payload: CropTaskScheduleBlueprintCreatePayload
  ): Observable<CropTaskScheduleBlueprint>;
  regenerate(cropId: number): Observable<CropTaskScheduleBlueprint[]>;
  update(
    cropId: number,
    blueprintId: number,
    payload: CropTaskScheduleBlueprintUpdatePayload
  ): Observable<CropTaskScheduleBlueprint>;
  destroy(cropId: number, blueprintId: number): Observable<void>;
}

export const CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY = new InjectionToken<CropTaskScheduleBlueprintGateway>(
  'CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY'
);
