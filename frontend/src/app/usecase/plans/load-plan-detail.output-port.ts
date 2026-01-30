import { InjectionToken } from '@angular/core';
import { PlanDetailDataDto } from './load-plan-detail.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPlanDetailOutputPort {
  present(dto: PlanDetailDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PLAN_DETAIL_OUTPUT_PORT = new InjectionToken<LoadPlanDetailOutputPort>(
  'LOAD_PLAN_DETAIL_OUTPUT_PORT'
);
