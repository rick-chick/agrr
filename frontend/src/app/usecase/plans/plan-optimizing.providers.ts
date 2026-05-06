import { Provider } from '@angular/core';
import { PlanOptimizationChannelGateway } from '../../adapters/plans/plan-optimization-channel.gateway';
import { PlanOptimizingPresenter } from '../../adapters/plans/plan-optimizing.presenter';
import { PLAN_OPTIMIZATION_GATEWAY } from './plan-optimization-gateway';
import { SUBSCRIBE_PLAN_OPTIMIZATION_OUTPUT_PORT } from './subscribe-plan-optimization.output-port';
import { SubscribePlanOptimizationUseCase } from './subscribe-plan-optimization.usecase';

export const PLAN_OPTIMIZING_PROVIDERS: readonly Provider[] = [
  PlanOptimizingPresenter,
  SubscribePlanOptimizationUseCase,
  { provide: SUBSCRIBE_PLAN_OPTIMIZATION_OUTPUT_PORT, useExisting: PlanOptimizingPresenter },
  { provide: PLAN_OPTIMIZATION_GATEWAY, useClass: PlanOptimizationChannelGateway }
];

export { PlanOptimizingPresenter } from '../../adapters/plans/plan-optimizing.presenter';
