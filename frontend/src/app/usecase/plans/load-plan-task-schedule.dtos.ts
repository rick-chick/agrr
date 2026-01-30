import { TaskScheduleResponse } from '../../models/plans/task-schedule';

export interface LoadPlanTaskScheduleInputDto {
  planId: number;
}

export interface PlanTaskScheduleDataDto {
  schedule: TaskScheduleResponse;
}
