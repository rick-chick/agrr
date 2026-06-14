import { SkipTaskScheduleItemInputDto } from './skip-task-schedule-item.dtos';

export interface SkipTaskScheduleItemInputPort {
  execute(dto: SkipTaskScheduleItemInputDto): void;
}
