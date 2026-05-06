import { Provider } from '@angular/core';
import { PublicPlanOptimizationChannelGateway } from '../../adapters/public-plans/public-plan-optimization.gateway';
import { PublicPlanOptimizingPresenter } from '../../adapters/public-plans/public-plan-optimizing.presenter';
import { PUBLIC_PLAN_OPTIMIZATION_GATEWAY } from './public-plan-optimization-gateway';
import { SUBSCRIBE_PUBLIC_PLAN_OPTIMIZATION_OUTPUT_PORT } from './subscribe-public-plan-optimization.output-port';
import { SubscribePublicPlanOptimizationUseCase } from './subscribe-public-plan-optimization.usecase';

export const PUBLIC_PLAN_OPTIMIZING_PROVIDERS: readonly Provider[] = [
  PublicPlanOptimizingPresenter,
  SubscribePublicPlanOptimizationUseCase,
  {
    provide: SUBSCRIBE_PUBLIC_PLAN_OPTIMIZATION_OUTPUT_PORT,
    useExisting: PublicPlanOptimizingPresenter
  },
  {
    provide: PUBLIC_PLAN_OPTIMIZATION_GATEWAY,
    useClass: PublicPlanOptimizationChannelGateway
  }
];

export { PublicPlanOptimizingPresenter } from '../../adapters/public-plans/public-plan-optimizing.presenter';
