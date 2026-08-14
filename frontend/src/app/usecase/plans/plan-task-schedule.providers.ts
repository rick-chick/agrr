import { Provider } from '@angular/core';
import { PlanOptimizationChannelGateway } from '../../adapters/plans/plan-optimization-channel.gateway';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanTaskSchedulePresenter } from '../../adapters/plans/plan-task-schedule.presenter';
import { LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT } from './load-plan-task-schedule.output-port';
import { LoadPlanTaskScheduleUseCase } from './load-plan-task-schedule.usecase';
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

export const PLAN_TASK_SCHEDULE_PROVIDERS: readonly Provider[] = [
  PlanTaskSchedulePresenter,
  LoadPlanTaskScheduleUseCase,
  RegenerateTaskScheduleUseCase,
  PollTaskScheduleSyncUseCase,
  SubscribeTaskScheduleSyncUseCase,
  CreateTaskScheduleItemUseCase,
  UpdateTaskScheduleItemUseCase,
  { provide: LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT, useExisting: PlanTaskSchedulePresenter },
  { provide: REGENERATE_TASK_SCHEDULE_OUTPUT_PORT, useExisting: PlanTaskSchedulePresenter },
  { provide: SUBSCRIBE_TASK_SCHEDULE_SYNC_OUTPUT_PORT, useExisting: PlanTaskSchedulePresenter },
  {
    provide: CREATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT,
    useFactory: (presenter: PlanTaskSchedulePresenter) => ({
      onSuccess: () => presenter.onItemMutationSuccess(),
      onError: (dto: Parameters<PlanTaskSchedulePresenter['onItemMutationError']>[0]) =>
        presenter.onItemMutationError(dto)
    }),
    deps: [PlanTaskSchedulePresenter]
  },
  {
    provide: UPDATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT,
    useFactory: (presenter: PlanTaskSchedulePresenter) => ({
      onSuccess: () => presenter.onItemMutationSuccess(),
      onError: (dto: Parameters<PlanTaskSchedulePresenter['onItemMutationError']>[0]) =>
        presenter.onItemMutationError(dto)
    }),
    deps: [PlanTaskSchedulePresenter]
  },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: PLAN_OPTIMIZATION_GATEWAY, useClass: PlanOptimizationChannelGateway }
];

export { PlanTaskSchedulePresenter } from '../../adapters/plans/plan-task-schedule.presenter';
