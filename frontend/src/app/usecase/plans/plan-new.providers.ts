import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanNewPresenter } from '../../adapters/plans/plan-new.presenter';
import { CreatePrivatePlanPresenter } from '../../adapters/private-plan-create/create-private-plan.presenter';
import { PrivatePlanCreateApiGateway } from '../../adapters/private-plan-create/private-plan-create-api.gateway';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropTaskScheduleBlueprintApiGateway } from '../../adapters/crops/crop-task-schedule-blueprint-api.gateway';
import { LOAD_PRIVATE_PLAN_FARMS_OUTPUT_PORT } from '../private-plan-create/load-private-plan-farms.output-port';
import { LoadPrivatePlanFarmsUseCase } from '../private-plan-create/load-private-plan-farms.usecase';
import { CREATE_PRIVATE_PLAN_OUTPUT_PORT } from '../private-plan-create/create-private-plan.output-port';
import { CreatePrivatePlanUseCase } from '../private-plan-create/create-private-plan.usecase';
import { LoadPlanNewCarryoverUseCase } from './load-plan-new-carryover.usecase';
import { LoadPlanNewReadinessUseCase } from './load-plan-new-readiness.usecase';
import { PRIVATE_PLAN_CREATE_GATEWAY } from '../private-plan-create/private-plan-create-gateway';
import { PLAN_GATEWAY } from './plan-gateway';
import { CROP_GATEWAY } from '../crops/crop-gateway';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from '../crops/crop-task-schedule-blueprint-gateway';

export const PLAN_NEW_PROVIDERS: readonly Provider[] = [
  PlanNewPresenter,
  CreatePrivatePlanPresenter,
  LoadPrivatePlanFarmsUseCase,
  CreatePrivatePlanUseCase,
  LoadPlanNewCarryoverUseCase,
  LoadPlanNewReadinessUseCase,
  { provide: LOAD_PRIVATE_PLAN_FARMS_OUTPUT_PORT, useExisting: PlanNewPresenter },
  { provide: CREATE_PRIVATE_PLAN_OUTPUT_PORT, useExisting: CreatePrivatePlanPresenter },
  { provide: PRIVATE_PLAN_CREATE_GATEWAY, useClass: PrivatePlanCreateApiGateway },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY, useClass: CropTaskScheduleBlueprintApiGateway }
];

export { PlanNewPresenter } from '../../adapters/plans/plan-new.presenter';
