import { InjectionToken } from '@angular/core';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPublicPlanResultsOutputPort {
  present(dto: CultivationPlanData): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT = new InjectionToken<LoadPublicPlanResultsOutputPort>(
  'LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT'
);
