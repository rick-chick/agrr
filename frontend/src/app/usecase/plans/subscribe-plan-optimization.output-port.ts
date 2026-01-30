import { InjectionToken } from '@angular/core';
import { PlanOptimizationMessageDto } from './subscribe-plan-optimization.dtos';

export interface SubscribePlanOptimizationOutputPort {
  present(dto: PlanOptimizationMessageDto): void;
}

export const SUBSCRIBE_PLAN_OPTIMIZATION_OUTPUT_PORT = new InjectionToken<SubscribePlanOptimizationOutputPort>(
  'SUBSCRIBE_PLAN_OPTIMIZATION_OUTPUT_PORT'
);
