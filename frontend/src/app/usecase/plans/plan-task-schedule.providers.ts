import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanTaskSchedulePresenter } from '../../adapters/plans/plan-task-schedule.presenter';
import { LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT } from './load-plan-task-schedule.output-port';
import { LoadPlanTaskScheduleUseCase } from './load-plan-task-schedule.usecase';
import { PLAN_GATEWAY } from './plan-gateway';

export const PLAN_TASK_SCHEDULE_PROVIDERS: readonly Provider[] = [
  PlanTaskSchedulePresenter,
  LoadPlanTaskScheduleUseCase,
  { provide: LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT, useExisting: PlanTaskSchedulePresenter },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
];

export { PlanTaskSchedulePresenter } from '../../adapters/plans/plan-task-schedule.presenter';
