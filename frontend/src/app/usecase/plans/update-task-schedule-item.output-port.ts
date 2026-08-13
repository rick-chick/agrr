import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateTaskScheduleItemOutputPort {
  onMutationSuccess(): void;
  onMutationError(dto: ErrorDto): void;
}

export const UPDATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT = new InjectionToken<UpdateTaskScheduleItemOutputPort>(
  'UPDATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT'
);
