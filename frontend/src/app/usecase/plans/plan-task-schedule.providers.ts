import { Provider } from '@angular/core';
import { PlanOptimizationChannelGateway } from '../../adapters/plans/plan-optimization-channel.gateway';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanTaskSchedulePresenter } from '../../adapters/plans/plan-task-schedule.presenter';
import { LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT } from './load-plan-task-schedule.output-port';
import { LoadPlanTaskScheduleUseCase } from './load-plan-task-schedule.usecase';
import { LoadPlanVsActualSummaryUseCase } from './load-plan-vs-actual-summary.usecase';
import { LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT } from './load-plan-vs-actual-summary.output-port';
import { PLAN_GATEWAY } from './plan-gateway';
import { PLAN_OPTIMIZATION_GATEWAY } from './plan-optimization-gateway';
import { REGENERATE_TASK_SCHEDULE_OUTPUT_PORT } from './regenerate-task-schedule.output-port';
import { RegenerateTaskScheduleUseCase } from './regenerate-task-schedule.usecase';
import { SUBSCRIBE_TASK_SCHEDULE_SYNC_OUTPUT_PORT } from './subscribe-task-schedule-sync.output-port';
import { PollTaskScheduleSyncUseCase } from './poll-task-schedule-sync.usecase';
import { SubscribeTaskScheduleSyncUseCase } from './subscribe-task-schedule-sync.usecase';
import { CREATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT } from './create-task-schedule-item.output-port';
import { CreateTaskScheduleItemUseCase } from './create-task-schedule-item.usecase';
import { UPDATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT } from './update-task-schedule-item.output-port';
import { UpdateTaskScheduleItemUseCase } from './update-task-schedule-item.usecase';
import { WorkRecordApiGateway } from '../../adapters/plans/work-record-api.gateway';
import { WORK_RECORD_GATEWAY } from './work-record-gateway';

export const PLAN_TASK_SCHEDULE_PROVIDERS: readonly Provider[] = [
  PlanTaskSchedulePresenter,
  LoadPlanTaskScheduleUseCase,
  LoadPlanVsActualSummaryUseCase,
  RegenerateTaskScheduleUseCase,
  PollTaskScheduleSyncUseCase,
  SubscribeTaskScheduleSyncUseCase,
  CreateTaskScheduleItemUseCase,
  UpdateTaskScheduleItemUseCase,
  { provide: LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT, useExisting: PlanTaskSchedulePresenter },
  {
    provide: LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT,
    useFactory: (presenter: PlanTaskSchedulePresenter) => ({
      present: (dto: Parameters<PlanTaskSchedulePresenter['presentVarianceSummary']>[0]) =>
        presenter.presentVarianceSummary(dto),
      onError: (dto: Parameters<PlanTaskSchedulePresenter['onVarianceError']>[0]) =>
        presenter.onVarianceError(dto)
    }),
    deps: [PlanTaskSchedulePresenter]
  },
  { provide: REGENERATE_TASK_SCHEDULE_OUTPUT_PORT, useExisting: PlanTaskSchedulePresenter },
  { provide: SUBSCRIBE_TASK_SCHEDULE_SYNC_OUTPUT_PORT, useExisting: PlanTaskSchedulePresenter },
  { provide: CREATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT, useExisting: PlanTaskSchedulePresenter },
  { provide: UPDATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT, useExisting: PlanTaskSchedulePresenter },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: WORK_RECORD_GATEWAY, useClass: WorkRecordApiGateway },
  { provide: PLAN_OPTIMIZATION_GATEWAY, useClass: PlanOptimizationChannelGateway }
];

export { PlanTaskSchedulePresenter } from '../../adapters/plans/plan-task-schedule.presenter';
