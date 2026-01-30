import { InjectionToken } from '@angular/core';
import { PublicPlanOptimizationMessageDto } from './subscribe-public-plan-optimization.dtos';

export interface SubscribePublicPlanOptimizationOutputPort {
  present(dto: PublicPlanOptimizationMessageDto): void;
}

export const SUBSCRIBE_PUBLIC_PLAN_OPTIMIZATION_OUTPUT_PORT =
  new InjectionToken<SubscribePublicPlanOptimizationOutputPort>(
    'SUBSCRIBE_PUBLIC_PLAN_OPTIMIZATION_OUTPUT_PORT'
  );
