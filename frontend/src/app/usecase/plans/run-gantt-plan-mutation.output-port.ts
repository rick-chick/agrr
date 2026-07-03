import { InjectionToken } from '@angular/core';
import { GanttPlanMutationOutcome } from '../../domain/plans/gantt-plan-mutation';
import { RunGanttPlanMutationResultDto } from './run-gantt-plan-mutation.dtos';

export interface RunGanttPlanMutationOutputPort {
  onMutationOutcome(outcome: GanttPlanMutationOutcome, context: RunGanttPlanMutationResultDto): void;
}

export const RUN_GANTT_PLAN_MUTATION_OUTPUT_PORT = new InjectionToken<RunGanttPlanMutationOutputPort>(
  'RUN_GANTT_PLAN_MUTATION_OUTPUT_PORT'
);
