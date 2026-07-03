import { LoadGanttPlanDataInputDto } from './load-gantt-plan-data.dtos';

export interface LoadGanttPlanDataInputPort {
  execute(dto: LoadGanttPlanDataInputDto): void;
}
