import { InjectionToken } from '@angular/core';
import { PublicPlanFarmsDataDto } from './load-public-plan-farms.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPublicPlanFarmsOutputPort {
  present(dto: PublicPlanFarmsDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PUBLIC_PLAN_FARMS_OUTPUT_PORT = new InjectionToken<LoadPublicPlanFarmsOutputPort>(
  'LOAD_PUBLIC_PLAN_FARMS_OUTPUT_PORT'
);
