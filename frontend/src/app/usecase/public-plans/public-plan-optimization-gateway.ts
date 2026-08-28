import { InjectionToken } from '@angular/core';
import { Channel } from 'actioncable';
import { CableChannelCallbacks } from '../../domain/cable/cable-channel-callbacks';
import { PublicPlanOptimizationMessageDto } from './subscribe-public-plan-optimization.dtos';

export interface PublicPlanOptimizationGateway {
  subscribe(
    planId: number,
    callbacks: CableChannelCallbacks<PublicPlanOptimizationMessageDto>
  ): Channel;
}

export const PUBLIC_PLAN_OPTIMIZATION_GATEWAY = new InjectionToken<PublicPlanOptimizationGateway>(
  'PUBLIC_PLAN_OPTIMIZATION_GATEWAY'
);
