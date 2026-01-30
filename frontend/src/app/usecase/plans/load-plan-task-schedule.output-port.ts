import { InjectionToken } from '@angular/core';
import { PlanTaskScheduleDataDto } from './load-plan-task-schedule.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPlanTaskScheduleOutputPort {
  present(dto: PlanTaskScheduleDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT = new InjectionToken<LoadPlanTaskScheduleOutputPort>(
  'LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT'
);
