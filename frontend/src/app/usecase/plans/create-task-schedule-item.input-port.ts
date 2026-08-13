import { CreateTaskScheduleItemInputDto } from './create-task-schedule-item.dtos';

export interface CreateTaskScheduleItemInputPort {
  execute(dto: CreateTaskScheduleItemInputDto): void;
}
