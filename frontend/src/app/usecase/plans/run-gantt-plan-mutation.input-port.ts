import { RunGanttPlanMutationInputDto } from './run-gantt-plan-mutation.dtos';

export interface RunGanttPlanMutationInputPort {
  execute(dto: RunGanttPlanMutationInputDto): void;
}
