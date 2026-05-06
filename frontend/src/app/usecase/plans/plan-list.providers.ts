import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanListPresenter } from '../../adapters/plans/plan-list.presenter';
import { DeletePlanUseCase } from './delete-plan.usecase';
import { DELETE_PLAN_OUTPUT_PORT } from './delete-plan.output-port';
import { LOAD_PLAN_LIST_OUTPUT_PORT } from './load-plan-list.output-port';
import { LoadPlanListUseCase } from './load-plan-list.usecase';
import { PLAN_GATEWAY } from './plan-gateway';

export const PLAN_LIST_PROVIDERS: readonly Provider[] = [
  PlanListPresenter,
  LoadPlanListUseCase,
  DeletePlanUseCase,
  { provide: LOAD_PLAN_LIST_OUTPUT_PORT, useExisting: PlanListPresenter },
  { provide: DELETE_PLAN_OUTPUT_PORT, useExisting: PlanListPresenter },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
];

export { PlanListPresenter } from '../../adapters/plans/plan-list.presenter';
