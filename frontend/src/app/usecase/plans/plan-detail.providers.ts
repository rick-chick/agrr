import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { GanttPlanApiGateway } from '../../adapters/plans/gantt-plan-api.gateway';
import { PlanDetailPresenter } from '../../adapters/plans/plan-detail.presenter';
import { LOAD_PLAN_DETAIL_OUTPUT_PORT } from './load-plan-detail.output-port';
import { LoadPlanDetailUseCase } from './load-plan-detail.usecase';
import { LoadPlanLearnCarryoverUseCase } from './load-plan-learn-carryover.usecase';
import { HydrateReorganizeOrchestrationUseCase } from './hydrate-reorganize-orchestration.usecase';
import { PLAN_GATEWAY } from './plan-gateway';
import { GANTT_PLAN_GATEWAY } from './gantt-plan-gateway';
import { PREVIEW_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT } from './preview-weather-reschedule-proposal.output-port';
import { PreviewWeatherRescheduleProposalUseCase } from './preview-weather-reschedule-proposal.usecase';
import { APPLY_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT } from './apply-weather-reschedule-proposal.output-port';
import { ApplyWeatherRescheduleProposalUseCase } from './apply-weather-reschedule-proposal.usecase';

export const PLAN_DETAIL_PROVIDERS: readonly Provider[] = [
  PlanDetailPresenter,
  LoadPlanDetailUseCase,
  LoadPlanLearnCarryoverUseCase,
  HydrateReorganizeOrchestrationUseCase,
  PreviewWeatherRescheduleProposalUseCase,
  ApplyWeatherRescheduleProposalUseCase,
  { provide: LOAD_PLAN_DETAIL_OUTPUT_PORT, useExisting: PlanDetailPresenter },
  {
    provide: PREVIEW_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT,
    useExisting: PlanDetailPresenter
  },
  {
    provide: APPLY_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT,
    useExisting: PlanDetailPresenter
  },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway },
  { provide: GANTT_PLAN_GATEWAY, useClass: GanttPlanApiGateway }
];

export { PlanDetailPresenter } from '../../adapters/plans/plan-detail.presenter';
