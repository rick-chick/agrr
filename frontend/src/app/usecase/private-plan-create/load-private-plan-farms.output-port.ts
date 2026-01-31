import { InjectionToken } from '@angular/core';
import { PrivatePlanFarmsDataDto } from './load-private-plan-farms.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPrivatePlanFarmsOutputPort {
  present(dto: PrivatePlanFarmsDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PRIVATE_PLAN_FARMS_OUTPUT_PORT = new InjectionToken<LoadPrivatePlanFarmsOutputPort>(
  'LOAD_PRIVATE_PLAN_FARMS_OUTPUT_PORT'
);