import { InjectionToken } from '@angular/core';
import { PublicPlanCropsDataDto } from './load-public-plan-crops.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPublicPlanCropsOutputPort {
  present(dto: PublicPlanCropsDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PUBLIC_PLAN_CROPS_OUTPUT_PORT = new InjectionToken<LoadPublicPlanCropsOutputPort>(
  'LOAD_PUBLIC_PLAN_CROPS_OUTPUT_PORT'
);
