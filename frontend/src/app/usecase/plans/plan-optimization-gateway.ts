import { InjectionToken } from '@angular/core';
import { Channel } from 'actioncable';
import { PlanOptimizationMessageDto } from './subscribe-plan-optimization.dtos';

export interface PlanOptimizationGateway {
  subscribe(
    planId: number,
    callbacks: { received: (message: PlanOptimizationMessageDto) => void }
  ): Channel;
}

export const PLAN_OPTIMIZATION_GATEWAY = new InjectionToken<PlanOptimizationGateway>(
  'PLAN_OPTIMIZATION_GATEWAY'
);
