import { InjectionToken } from '@angular/core';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface PlanVsActualSummaryDataDto {
  summary: PlanVsActualSummary;
  loadGeneration: number;
}

export interface LoadPlanVsActualSummaryOutputPort {
  present(dto: PlanVsActualSummaryDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT =
  new InjectionToken<LoadPlanVsActualSummaryOutputPort>(
    'LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT'
  );
