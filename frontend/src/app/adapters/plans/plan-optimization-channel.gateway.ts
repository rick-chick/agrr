import { Injectable } from '@angular/core';
import { Channel } from 'actioncable';
import { OptimizationService } from '../../services/plans/optimization.service';
import { PlanOptimizationGateway } from '../../usecase/plans/plan-optimization-gateway';
import { PlanOptimizationMessageDto } from '../../usecase/plans/subscribe-plan-optimization.dtos';

@Injectable()
export class PlanOptimizationChannelGateway implements PlanOptimizationGateway {
  constructor(private readonly optimizationService: OptimizationService) {}

  subscribe(
    planId: number,
    callbacks: { received: (message: PlanOptimizationMessageDto) => void }
  ): Channel {
    return this.optimizationService.subscribe(
      'PlansOptimizationChannel',
      { cultivation_plan_id: planId },
      { received: callbacks.received }
    );
  }
}
