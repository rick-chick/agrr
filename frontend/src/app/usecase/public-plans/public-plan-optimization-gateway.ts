import { InjectionToken } from '@angular/core';
import { Channel } from 'actioncable';
import { PublicPlanOptimizationMessageDto } from './subscribe-public-plan-optimization.dtos';

export interface PublicPlanOptimizationGateway {
  subscribe(
    planId: number,
    callbacks: { received: (message: PublicPlanOptimizationMessageDto) => void }
  ): Channel;
}

export const PUBLIC_PLAN_OPTIMIZATION_GATEWAY = new InjectionToken<PublicPlanOptimizationGateway>(
  'PUBLIC_PLAN_OPTIMIZATION_GATEWAY'
);
