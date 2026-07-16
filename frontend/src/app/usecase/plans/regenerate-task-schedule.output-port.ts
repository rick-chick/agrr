import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { RegenerateTaskScheduleResponseDto } from './regenerate-task-schedule-response.dtos';

export interface RegenerateTaskScheduleOutputPort {
  onRegenerateStarted(): void;
  onRegenerateSuccess(dto: RegenerateTaskScheduleResponseDto): void;
  onRegenerateError(dto: ErrorDto): void;
}

export const REGENERATE_TASK_SCHEDULE_OUTPUT_PORT = new InjectionToken<RegenerateTaskScheduleOutputPort>(
  'REGENERATE_TASK_SCHEDULE_OUTPUT_PORT'
);
