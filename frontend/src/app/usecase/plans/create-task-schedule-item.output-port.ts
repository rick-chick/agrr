import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreateTaskScheduleItemOutputPort {
  onMutationSuccess(): void;
  onMutationError(dto: ErrorDto): void;
}

export const CREATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT = new InjectionToken<CreateTaskScheduleItemOutputPort>(
  'CREATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT'
);
