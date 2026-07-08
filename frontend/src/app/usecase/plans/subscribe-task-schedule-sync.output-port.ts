import { InjectionToken } from '@angular/core';
import { TaskScheduleSyncMessageDto } from './subscribe-task-schedule-sync.dtos';

export interface SubscribeTaskScheduleSyncOutputPort {
  onTaskScheduleSync(message: TaskScheduleSyncMessageDto): void;
}

export const SUBSCRIBE_TASK_SCHEDULE_SYNC_OUTPUT_PORT =
  new InjectionToken<SubscribeTaskScheduleSyncOutputPort>(
    'SUBSCRIBE_TASK_SCHEDULE_SYNC_OUTPUT_PORT'
  );
