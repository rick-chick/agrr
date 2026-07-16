import { TaskScheduleSyncState } from '../../domain/plans/task-schedule-sync-state';

export interface RegenerateTaskScheduleResponseDto {
  success: boolean;
  task_schedule_sync_state: TaskScheduleSyncState | string;
}
