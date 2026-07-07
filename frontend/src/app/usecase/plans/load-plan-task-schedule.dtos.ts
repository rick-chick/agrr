import { TaskScheduleResponse } from '../../models/plans/task-schedule';

export interface LoadPlanTaskScheduleInputDto {
  planId: number;
  scope?: 'plan' | 'week';
  weekStart?: string;
  fieldCultivationId?: number;
}

export interface PlanTaskScheduleDataDto {
  schedule: TaskScheduleResponse;
}
