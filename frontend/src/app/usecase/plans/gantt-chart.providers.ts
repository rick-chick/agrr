import { Provider } from '@angular/core';
import { GanttPlanApiGateway } from '../../adapters/plans/gantt-plan-api.gateway';
import { DemoGanttPlanGateway } from '../../adapters/plans/demo-gantt-plan.gateway';
import { GanttChartPresenter } from '../../adapters/plans/gantt-chart.presenter';
import { GANTT_PLAN_GATEWAY } from './gantt-plan-gateway';
import { LOAD_GANTT_PLAN_DATA_OUTPUT_PORT } from './load-gantt-plan-data.output-port';
import { LoadGanttPlanDataUseCase } from './load-gantt-plan-data.usecase';
import { RUN_GANTT_PLAN_MUTATION_OUTPUT_PORT } from './run-gantt-plan-mutation.output-port';
import { RunGanttPlanMutationUseCase } from './run-gantt-plan-mutation.usecase';

export const GANTT_CHART_SHARED_PROVIDERS: readonly Provider[] = [
  GanttChartPresenter,
  LoadGanttPlanDataUseCase,
  RunGanttPlanMutationUseCase,
  { provide: LOAD_GANTT_PLAN_DATA_OUTPUT_PORT, useExisting: GanttChartPresenter },
  { provide: RUN_GANTT_PLAN_MUTATION_OUTPUT_PORT, useExisting: GanttChartPresenter }
];

export const GANTT_CHART_API_PROVIDERS: readonly Provider[] = [
  ...GANTT_CHART_SHARED_PROVIDERS,
  GanttPlanApiGateway,
  { provide: GANTT_PLAN_GATEWAY, useClass: GanttPlanApiGateway }
];

export const GANTT_CHART_DEMO_PROVIDERS: readonly Provider[] = [
  ...GANTT_CHART_SHARED_PROVIDERS,
  DemoGanttPlanGateway,
  { provide: GANTT_PLAN_GATEWAY, useExisting: DemoGanttPlanGateway }
];

export { GanttChartPresenter } from '../../adapters/plans/gantt-chart.presenter';
