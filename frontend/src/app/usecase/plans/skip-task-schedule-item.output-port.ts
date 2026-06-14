import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface SkipTaskScheduleItemOutputPort {
  onSuccess(): void;
  onError(dto: ErrorDto): void;
}

export const SKIP_TASK_SCHEDULE_ITEM_OUTPUT_PORT = new InjectionToken<SkipTaskScheduleItemOutputPort>(
  'SKIP_TASK_SCHEDULE_ITEM_OUTPUT_PORT'
);
