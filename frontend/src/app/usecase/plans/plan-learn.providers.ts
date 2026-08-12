import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PlanLearnPresenter } from '../../adapters/plans/plan-learn.presenter';
import { LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT } from './load-plan-task-schedule.output-port';
import { LoadPlanTaskScheduleUseCase } from './load-plan-task-schedule.usecase';
import { LoadPlanVsActualSummaryUseCase } from './load-plan-vs-actual-summary.usecase';
import { LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT } from './load-plan-vs-actual-summary.output-port';
import { PLAN_GATEWAY } from './plan-gateway';

export const PLAN_LEARN_PROVIDERS: readonly Provider[] = [
  PlanLearnPresenter,
  LoadPlanTaskScheduleUseCase,
  LoadPlanVsActualSummaryUseCase,
  { provide: LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT, useExisting: PlanLearnPresenter },
  {
    provide: LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT,
    useFactory: (presenter: PlanLearnPresenter) => ({
      present: (dto: Parameters<PlanLearnPresenter['presentVarianceSummary']>[0]) =>
        presenter.presentVarianceSummary(dto),
      onError: (dto: Parameters<PlanLearnPresenter['onVarianceError']>[0]) =>
        presenter.onVarianceError(dto)
    }),
    deps: [PlanLearnPresenter]
  },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
];

export { PlanLearnPresenter } from '../../adapters/plans/plan-learn.presenter';
