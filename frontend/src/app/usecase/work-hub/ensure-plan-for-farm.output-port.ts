import { InjectionToken } from '@angular/core';
import { EnsurePlanForFarmSuccessDto } from './ensure-plan-for-farm.dtos';

export interface EnsurePlanForFarmOutputPort {
  onSuccess(dto: EnsurePlanForFarmSuccessDto): void;
  onError(dto: { message: string }): void;
}

export const ENSURE_PLAN_FOR_FARM_OUTPUT_PORT = new InjectionToken<EnsurePlanForFarmOutputPort>(
  'ENSURE_PLAN_FOR_FARM_OUTPUT_PORT'
);
