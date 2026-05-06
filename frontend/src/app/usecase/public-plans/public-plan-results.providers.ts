import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PublicPlanApiGateway } from '../../adapters/public-plans/public-plan-api.gateway';
import { PublicPlanResultsPresenter } from '../../adapters/public-plans/public-plan-results.presenter';
import { LoadPublicPlanResultsUseCase } from './load-public-plan-results.usecase';
import { LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT } from './load-public-plan-results.output-port';
import { PLAN_GATEWAY } from '../plans/plan-gateway';
import { PUBLIC_PLAN_GATEWAY } from './public-plan-gateway';
import { SAVE_PUBLIC_PLAN_OUTPUT_PORT } from './save-public-plan.output-port';
import { SavePublicPlanUseCase } from './save-public-plan.usecase';

export const PUBLIC_PLAN_RESULTS_PROVIDERS: readonly Provider[] = [
  PublicPlanResultsPresenter,
  LoadPublicPlanResultsUseCase,
  SavePublicPlanUseCase,
  { provide: LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT, useExisting: PublicPlanResultsPresenter },
  { provide: SAVE_PUBLIC_PLAN_OUTPUT_PORT, useExisting: PublicPlanResultsPresenter },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: PUBLIC_PLAN_GATEWAY, useClass: PublicPlanApiGateway }
];

export { PublicPlanResultsPresenter } from '../../adapters/public-plans/public-plan-results.presenter';
