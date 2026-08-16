import { Provider } from '@angular/core';
import { PlanOptimizationChannelGateway } from '../../adapters/plans/plan-optimization-channel.gateway';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanOptimizingPresenter } from '../../adapters/plans/plan-optimizing.presenter';
import { PLAN_OPTIMIZATION_GATEWAY } from './plan-optimization-gateway';
import { SUBSCRIBE_PLAN_OPTIMIZATION_OUTPUT_PORT } from './subscribe-plan-optimization.output-port';
import { SubscribePlanOptimizationUseCase } from './subscribe-plan-optimization.usecase';
import { LoadPlanLearnCarryoverUseCase } from './load-plan-learn-carryover.usecase';
import { HydrateReorganizeOrchestrationUseCase } from './hydrate-reorganize-orchestration.usecase';
import { PLAN_GATEWAY } from './plan-gateway';

export const PLAN_OPTIMIZING_PROVIDERS: readonly Provider[] = [
  PlanOptimizingPresenter,
  SubscribePlanOptimizationUseCase,
  LoadPlanLearnCarryoverUseCase,
  HydrateReorganizeOrchestrationUseCase,
  { provide: SUBSCRIBE_PLAN_OPTIMIZATION_OUTPUT_PORT, useExisting: PlanOptimizingPresenter },
  { provide: PLAN_OPTIMIZATION_GATEWAY, useClass: PlanOptimizationChannelGateway },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
];

export { PlanOptimizingPresenter } from '../../adapters/plans/plan-optimizing.presenter';
