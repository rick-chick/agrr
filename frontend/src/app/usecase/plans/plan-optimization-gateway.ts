import { InjectionToken } from '@angular/core';
import { Channel } from 'actioncable';
import { CableChannelCallbacks } from '../../domain/cable/cable-channel-callbacks';
import { PlanOptimizationMessageDto } from './subscribe-plan-optimization.dtos';
import { TaskScheduleSyncMessageDto } from './subscribe-task-schedule-sync.dtos';

export interface PlanOptimizationGateway {
  subscribe(
    planId: number,
    callbacks: CableChannelCallbacks<PlanOptimizationMessageDto>
  ): Channel;

  subscribeTaskScheduleSync(
    planId: number,
    callbacks: CableChannelCallbacks<TaskScheduleSyncMessageDto>
  ): Channel;
}

export const PLAN_OPTIMIZATION_GATEWAY = new InjectionToken<PlanOptimizationGateway>(
  'PLAN_OPTIMIZATION_GATEWAY'
);
