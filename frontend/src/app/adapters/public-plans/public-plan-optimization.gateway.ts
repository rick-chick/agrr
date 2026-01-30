import { Injectable } from '@angular/core';
import { Channel } from 'actioncable';
import { OptimizationService } from '../../services/plans/optimization.service';
import { PublicPlanOptimizationGateway } from '../../usecase/public-plans/public-plan-optimization-gateway';
import { PublicPlanOptimizationMessageDto } from '../../usecase/public-plans/subscribe-public-plan-optimization.dtos';

@Injectable()
export class PublicPlanOptimizationChannelGateway
  implements PublicPlanOptimizationGateway
{
  constructor(private readonly optimizationService: OptimizationService) {}

  subscribe(
    planId: number,
    callbacks: { received: (message: PublicPlanOptimizationMessageDto) => void }
  ): Channel {
    return this.optimizationService.subscribe(
      'OptimizationChannel',
      { cultivation_plan_id: planId },
      { received: callbacks.received }
    );
  }
}
