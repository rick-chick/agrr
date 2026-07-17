import { TaskScheduleResponse } from '../../models/plans/task-schedule';

export interface LoadPlanTaskScheduleInputDto {
  planId: number;
  fieldCultivationId?: number;
  loadGeneration?: number;
}

export interface PlanTaskScheduleDataDto {
  schedule: TaskScheduleResponse;
  loadGeneration?: number;
}
