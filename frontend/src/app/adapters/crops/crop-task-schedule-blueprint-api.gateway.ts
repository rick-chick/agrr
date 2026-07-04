import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';
import {
  CropTaskScheduleBlueprintGateway,
  CropTaskScheduleBlueprintCreatePayload,
  CropTaskScheduleBlueprintUpdatePayload
} from '../../usecase/crops/crop-task-schedule-blueprint-gateway';

@Injectable()
export class CropTaskScheduleBlueprintApiGateway implements CropTaskScheduleBlueprintGateway {
  constructor(private readonly client: MastersClientService) {}

  list(cropId: number): Observable<CropTaskScheduleBlueprint[]> {
    return this.client.get<CropTaskScheduleBlueprint[]>(`/crops/${cropId}/task_schedule_blueprints`);
  }

  create(
    cropId: number,
    payload: CropTaskScheduleBlueprintCreatePayload
  ): Observable<CropTaskScheduleBlueprint> {
    return this.client.post<CropTaskScheduleBlueprint>(
      `/crops/${cropId}/task_schedule_blueprints`,
      payload
    );
  }

  regenerate(cropId: number): Observable<CropTaskScheduleBlueprint[]> {
    return this.client.post<CropTaskScheduleBlueprint[]>(
      `/crops/${cropId}/task_schedule_blueprints/regenerate`,
      {}
    );
  }

  update(
    cropId: number,
    blueprintId: number,
    payload: CropTaskScheduleBlueprintUpdatePayload
  ): Observable<CropTaskScheduleBlueprint> {
    return this.client.patch<CropTaskScheduleBlueprint>(
      `/crops/${cropId}/task_schedule_blueprints/${blueprintId}`,
      payload
    );
  }

  destroy(cropId: number, blueprintId: number): Observable<void> {
    return this.client.delete<void>(`/crops/${cropId}/task_schedule_blueprints/${blueprintId}`);
  }
}
