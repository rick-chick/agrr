import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanWorkPresenter } from '../../adapters/plans/plan-work.presenter';
import { WorkRecordApiGateway } from '../../adapters/plans/work-record-api.gateway';
import { LOAD_WORK_DAY_LIST_OUTPUT_PORT } from './load-work-day-list.output-port';
import { LoadWorkDayListUseCase } from './load-work-day-list.usecase';
import { PLAN_GATEWAY } from './plan-gateway';
import { SKIP_TASK_SCHEDULE_ITEM_OUTPUT_PORT } from './skip-task-schedule-item.output-port';
import { SkipTaskScheduleItemUseCase } from './skip-task-schedule-item.usecase';
import { WORK_RECORD_GATEWAY } from './work-record-gateway';

export const PLAN_WORK_PROVIDERS: readonly Provider[] = [
  PlanWorkPresenter,
  LoadWorkDayListUseCase,
  SkipTaskScheduleItemUseCase,
  { provide: LOAD_WORK_DAY_LIST_OUTPUT_PORT, useExisting: PlanWorkPresenter },
  { provide: SKIP_TASK_SCHEDULE_ITEM_OUTPUT_PORT, useExisting: PlanWorkPresenter },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: WORK_RECORD_GATEWAY, useClass: WorkRecordApiGateway }
];

export { PlanWorkPresenter } from '../../adapters/plans/plan-work.presenter';
