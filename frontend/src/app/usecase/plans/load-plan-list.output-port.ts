import { InjectionToken } from '@angular/core';
import { PlanListDataDto } from './load-plan-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPlanListOutputPort {
  present(dto: PlanListDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PLAN_LIST_OUTPUT_PORT = new InjectionToken<LoadPlanListOutputPort>(
  'LOAD_PLAN_LIST_OUTPUT_PORT'
);
