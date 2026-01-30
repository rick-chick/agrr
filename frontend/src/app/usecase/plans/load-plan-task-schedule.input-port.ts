import { LoadPlanTaskScheduleInputDto } from './load-plan-task-schedule.dtos';

export interface LoadPlanTaskScheduleInputPort {
  execute(dto: LoadPlanTaskScheduleInputDto): void;
}
