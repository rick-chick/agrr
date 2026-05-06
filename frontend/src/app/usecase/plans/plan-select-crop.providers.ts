import { Provider } from '@angular/core';
import { PlanSelectCropPresenter } from '../../adapters/plans/plan-select-crop.presenter';
import { PrivatePlanCreateApiGateway } from '../../adapters/private-plan-create/private-plan-create-api.gateway';
import { CreatePrivatePlanUseCase } from '../private-plan-create/create-private-plan.usecase';
import { CREATE_PRIVATE_PLAN_OUTPUT_PORT } from '../private-plan-create/create-private-plan.output-port';
import { LOAD_PRIVATE_PLAN_SELECT_CROP_CONTEXT_OUTPUT_PORT } from '../private-plan-create/load-private-plan-select-crop-context.output-port';
import { LoadPrivatePlanSelectCropContextUseCase } from '../private-plan-create/load-private-plan-select-crop-context.usecase';
import { PRIVATE_PLAN_CREATE_GATEWAY } from '../private-plan-create/private-plan-create-gateway';

export const PLAN_SELECT_CROP_PROVIDERS: readonly Provider[] = [
  PlanSelectCropPresenter,
  LoadPrivatePlanSelectCropContextUseCase,
  CreatePrivatePlanUseCase,
  { provide: LOAD_PRIVATE_PLAN_SELECT_CROP_CONTEXT_OUTPUT_PORT, useExisting: PlanSelectCropPresenter },
  { provide: CREATE_PRIVATE_PLAN_OUTPUT_PORT, useExisting: PlanSelectCropPresenter },
  { provide: PRIVATE_PLAN_CREATE_GATEWAY, useClass: PrivatePlanCreateApiGateway }
];

export { PlanSelectCropPresenter } from '../../adapters/plans/plan-select-crop.presenter';
