import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanDetailPresenter } from '../../adapters/plans/plan-detail.presenter';
import { LOAD_PLAN_DETAIL_OUTPUT_PORT } from './load-plan-detail.output-port';
import { LoadPlanDetailUseCase } from './load-plan-detail.usecase';
import { PLAN_GATEWAY } from './plan-gateway';

export const PLAN_DETAIL_PROVIDERS: readonly Provider[] = [
  PlanDetailPresenter,
  LoadPlanDetailUseCase,
  { provide: LOAD_PLAN_DETAIL_OUTPUT_PORT, useExisting: PlanDetailPresenter },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
];

export { PlanDetailPresenter } from '../../adapters/plans/plan-detail.presenter';
