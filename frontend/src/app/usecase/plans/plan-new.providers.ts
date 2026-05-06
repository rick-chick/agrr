import { Provider } from '@angular/core';
import { PlanNewPresenter } from '../../adapters/plans/plan-new.presenter';
import { PrivatePlanCreateApiGateway } from '../../adapters/private-plan-create/private-plan-create-api.gateway';
import { LOAD_PRIVATE_PLAN_FARMS_OUTPUT_PORT } from '../private-plan-create/load-private-plan-farms.output-port';
import { LoadPrivatePlanFarmsUseCase } from '../private-plan-create/load-private-plan-farms.usecase';
import { PRIVATE_PLAN_CREATE_GATEWAY } from '../private-plan-create/private-plan-create-gateway';

export const PLAN_NEW_PROVIDERS: readonly Provider[] = [
  PlanNewPresenter,
  LoadPrivatePlanFarmsUseCase,
  { provide: LOAD_PRIVATE_PLAN_FARMS_OUTPUT_PORT, useExisting: PlanNewPresenter },
  { provide: PRIVATE_PLAN_CREATE_GATEWAY, useClass: PrivatePlanCreateApiGateway }
];

export { PlanNewPresenter } from '../../adapters/plans/plan-new.presenter';
