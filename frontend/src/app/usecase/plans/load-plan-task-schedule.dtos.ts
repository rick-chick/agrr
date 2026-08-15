import { TaskScheduleResponse } from '../../models/plans/task-schedule';

export interface LoadPlanTaskScheduleInputDto {
  planId: number;
  fieldCultivationId?: number;
  category?: 'general' | 'fertilizer' | 'pest_control';
  loadGeneration?: number;
}

export interface PlanTaskScheduleDataDto {
  schedule: TaskScheduleResponse;
  loadGeneration?: number;
}
