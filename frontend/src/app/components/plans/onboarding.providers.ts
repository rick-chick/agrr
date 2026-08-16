import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropTaskScheduleBlueprintApiGateway } from '../../adapters/crops/crop-task-schedule-blueprint-api.gateway';
import { PrivatePlanCreateApiGateway } from '../../adapters/private-plan-create/private-plan-create-api.gateway';
import { CROP_GATEWAY } from '../../usecase/crops/crop-gateway';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from '../../usecase/crops/crop-task-schedule-blueprint-gateway';
import { LoadPlanNewReadinessUseCase } from '../../usecase/plans/load-plan-new-readiness.usecase';
import { PRIVATE_PLAN_CREATE_GATEWAY } from '../../usecase/private-plan-create/private-plan-create-gateway';

export const ONBOARDING_PROVIDERS: readonly Provider[] = [
  LoadPlanNewReadinessUseCase,
  { provide: PRIVATE_PLAN_CREATE_GATEWAY, useClass: PrivatePlanCreateApiGateway },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY, useClass: CropTaskScheduleBlueprintApiGateway }
];
