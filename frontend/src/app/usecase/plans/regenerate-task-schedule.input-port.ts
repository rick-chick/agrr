import { RegenerateTaskScheduleInputDto } from './regenerate-task-schedule.dtos';

export interface RegenerateTaskScheduleInputPort {
  execute(dto: RegenerateTaskScheduleInputDto): void;
}
