import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { WorkVarianceApiGateway } from '../../adapters/work-variance/work-variance-api.gateway';
import { WorkVariancePresenter } from '../../adapters/work-variance/work-variance.presenter';
import { PLAN_GATEWAY } from '../plans/plan-gateway';
import { WORK_VARIANCE_GATEWAY } from './work-variance-gateway';
import { WORK_VARIANCE_INIT_OUTPUT_PORT } from './work-variance-init.output-port';
import { WorkVarianceInitUseCase } from './work-variance-init.usecase';

export const WORK_VARIANCE_PROVIDERS: readonly Provider[] = [
  WorkVariancePresenter,
  WorkVarianceInitUseCase,
  { provide: WORK_VARIANCE_INIT_OUTPUT_PORT, useExisting: WorkVariancePresenter },
  { provide: WORK_VARIANCE_GATEWAY, useClass: WorkVarianceApiGateway },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
];

export { WorkVariancePresenter } from '../../adapters/work-variance/work-variance.presenter';
