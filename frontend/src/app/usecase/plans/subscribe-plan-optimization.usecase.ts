import { Inject, Injectable } from '@angular/core';
import { SubscribePlanOptimizationInputDto } from './subscribe-plan-optimization.dtos';
import { SubscribePlanOptimizationInputPort } from './subscribe-plan-optimization.input-port';
import {
  SubscribePlanOptimizationOutputPort,
  SUBSCRIBE_PLAN_OPTIMIZATION_OUTPUT_PORT
} from './subscribe-plan-optimization.output-port';
import { PLAN_OPTIMIZATION_GATEWAY, PlanOptimizationGateway } from './plan-optimization-gateway';

@Injectable()
export class SubscribePlanOptimizationUseCase implements SubscribePlanOptimizationInputPort {
  constructor(
    @Inject(SUBSCRIBE_PLAN_OPTIMIZATION_OUTPUT_PORT) private readonly outputPort: SubscribePlanOptimizationOutputPort,
    @Inject(PLAN_OPTIMIZATION_GATEWAY) private readonly optimizationGateway: PlanOptimizationGateway
  ) {}

  execute(dto: SubscribePlanOptimizationInputDto): void {
    const channel = this.optimizationGateway.subscribe(dto.planId, {
      received: (message) => this.outputPort.present(message)
    });
    dto.onSubscribed?.(channel);
  }
}
