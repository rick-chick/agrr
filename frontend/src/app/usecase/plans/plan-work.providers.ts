import { Provider } from '@angular/core';
import { PlanOptimizationChannelGateway } from '../../adapters/plans/plan-optimization-channel.gateway';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanWorkPresenter } from '../../adapters/plans/plan-work.presenter';
import { WorkRecordApiGateway } from '../../adapters/plans/work-record-api.gateway';
import { CREATE_WORK_RECORD_OUTPUT_PORT } from './create-work-record.output-port';
import { CreateWorkRecordUseCase } from './create-work-record.usecase';
import { LOAD_WORK_DAY_LIST_OUTPUT_PORT } from './load-work-day-list.output-port';
import { LoadWorkDayListUseCase } from './load-work-day-list.usecase';
import { PLAN_GATEWAY } from './plan-gateway';
import { PLAN_OPTIMIZATION_GATEWAY } from './plan-optimization-gateway';
import { REGENERATE_TASK_SCHEDULE_OUTPUT_PORT } from './regenerate-task-schedule.output-port';
import { RegenerateTaskScheduleUseCase } from './regenerate-task-schedule.usecase';
import { SKIP_TASK_SCHEDULE_ITEM_OUTPUT_PORT } from './skip-task-schedule-item.output-port';
import { SkipTaskScheduleItemUseCase } from './skip-task-schedule-item.usecase';
import { SUBSCRIBE_TASK_SCHEDULE_SYNC_OUTPUT_PORT } from './subscribe-task-schedule-sync.output-port';
import { SubscribeTaskScheduleSyncUseCase } from './subscribe-task-schedule-sync.usecase';
import { WORK_RECORD_GATEWAY } from './work-record-gateway';

export const PLAN_WORK_PROVIDERS: readonly Provider[] = [
  PlanWorkPresenter,
  LoadWorkDayListUseCase,
  SkipTaskScheduleItemUseCase,
  CreateWorkRecordUseCase,
  RegenerateTaskScheduleUseCase,
  SubscribeTaskScheduleSyncUseCase,
  { provide: LOAD_WORK_DAY_LIST_OUTPUT_PORT, useExisting: PlanWorkPresenter },
  { provide: SKIP_TASK_SCHEDULE_ITEM_OUTPUT_PORT, useExisting: PlanWorkPresenter },
  { provide: CREATE_WORK_RECORD_OUTPUT_PORT, useExisting: PlanWorkPresenter },
  { provide: REGENERATE_TASK_SCHEDULE_OUTPUT_PORT, useExisting: PlanWorkPresenter },
  { provide: SUBSCRIBE_TASK_SCHEDULE_SYNC_OUTPUT_PORT, useExisting: PlanWorkPresenter },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: WORK_RECORD_GATEWAY, useClass: WorkRecordApiGateway },
  { provide: PLAN_OPTIMIZATION_GATEWAY, useClass: PlanOptimizationChannelGateway }
];

export { PlanWorkPresenter } from '../../adapters/plans/plan-work.presenter';
