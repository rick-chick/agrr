import { Inject, Injectable } from '@angular/core';
import { SubscribePublicPlanOptimizationInputDto } from './subscribe-public-plan-optimization.dtos';
import { SubscribePublicPlanOptimizationInputPort } from './subscribe-public-plan-optimization.input-port';
import {
  SubscribePublicPlanOptimizationOutputPort,
  SUBSCRIBE_PUBLIC_PLAN_OPTIMIZATION_OUTPUT_PORT
} from './subscribe-public-plan-optimization.output-port';
import {
  PUBLIC_PLAN_OPTIMIZATION_GATEWAY,
  PublicPlanOptimizationGateway
} from './public-plan-optimization-gateway';

@Injectable()
export class SubscribePublicPlanOptimizationUseCase
  implements SubscribePublicPlanOptimizationInputPort
{
  constructor(
    @Inject(SUBSCRIBE_PUBLIC_PLAN_OPTIMIZATION_OUTPUT_PORT)
    private readonly outputPort: SubscribePublicPlanOptimizationOutputPort,
    @Inject(PUBLIC_PLAN_OPTIMIZATION_GATEWAY)
    private readonly optimizationGateway: PublicPlanOptimizationGateway
  ) {}

  execute(dto: SubscribePublicPlanOptimizationInputDto): void {
    const channel = this.optimizationGateway.subscribe(dto.planId, {
      received: (message) => this.outputPort.present(message)
    });
    dto.onSubscribed?.(channel);
  }
}
