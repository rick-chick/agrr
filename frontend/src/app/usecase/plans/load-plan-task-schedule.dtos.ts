import { TaskScheduleResponse } from '../../models/plans/task-schedule';

export interface LoadPlanTaskScheduleInputDto {
  planId: number;
  fieldCultivationId?: number;
}

export interface PlanTaskScheduleDataDto {
  schedule: TaskScheduleResponse;
}
