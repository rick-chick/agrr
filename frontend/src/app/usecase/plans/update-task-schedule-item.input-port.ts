import { UpdateTaskScheduleItemInputDto } from './update-task-schedule-item.dtos';

export interface UpdateTaskScheduleItemInputPort {
  execute(dto: UpdateTaskScheduleItemInputDto): void;
}
