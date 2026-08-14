import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { LoadPlanWorkFrostRiskDataDto } from './load-plan-work-frost-risk.dtos';

export interface LoadPlanWorkFrostRiskOutputPort {
  present(dto: LoadPlanWorkFrostRiskDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PLAN_WORK_FROST_RISK_OUTPUT_PORT = new InjectionToken<LoadPlanWorkFrostRiskOutputPort>(
  'LOAD_PLAN_WORK_FROST_RISK_OUTPUT_PORT'
);
