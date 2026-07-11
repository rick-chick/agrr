import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PrivatePlanCreateApiGateway } from '../../adapters/private-plan-create/private-plan-create-api.gateway';
import { WorkHubApiGateway } from '../../adapters/work-hub/work-hub-api.gateway';
import { WorkHubPresenter } from '../../adapters/work-hub/work-hub.presenter';
import { PLAN_GATEWAY } from '../plans/plan-gateway';
import { PRIVATE_PLAN_CREATE_GATEWAY } from '../private-plan-create/private-plan-create-gateway';
import { WORK_HUB_GATEWAY } from './work-hub-gateway';
import { ENSURE_PLAN_FOR_FARM_OUTPUT_PORT } from './ensure-plan-for-farm.output-port';
import { EnsurePlanForFarmUseCase } from './ensure-plan-for-farm.usecase';
import { WORK_HUB_INIT_OUTPUT_PORT } from './work-hub-init.output-port';
import { WorkHubInitUseCase } from './work-hub-init.usecase';
import { LOAD_CROSS_FARM_SCHEDULE_OUTPUT_PORT } from './load-cross-farm-schedule.output-port';
import { LoadCrossFarmScheduleUseCase } from './load-cross-farm-schedule.usecase';

export const WORK_HUB_PROVIDERS: readonly Provider[] = [
  WorkHubPresenter,
  WorkHubInitUseCase,
  EnsurePlanForFarmUseCase,
  LoadCrossFarmScheduleUseCase,
  { provide: WORK_HUB_INIT_OUTPUT_PORT, useExisting: WorkHubPresenter },
  { provide: ENSURE_PLAN_FOR_FARM_OUTPUT_PORT, useExisting: WorkHubPresenter },
  { provide: LOAD_CROSS_FARM_SCHEDULE_OUTPUT_PORT, useExisting: WorkHubPresenter },
  { provide: WORK_HUB_GATEWAY, useClass: WorkHubApiGateway },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: PRIVATE_PLAN_CREATE_GATEWAY, useClass: PrivatePlanCreateApiGateway }
];

export { WorkHubPresenter } from '../../adapters/work-hub/work-hub.presenter';
