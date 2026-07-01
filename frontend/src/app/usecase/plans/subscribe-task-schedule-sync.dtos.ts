import { Channel } from 'actioncable';
import { TaskScheduleSyncState } from '../../models/plans/task-schedule';

export interface SubscribeTaskScheduleSyncInputDto {
  planId: number;
  onSubscribed?: (channel: Channel) => void;
}

export interface TaskScheduleSyncMessageDto {
  syncState: TaskScheduleSyncState | string;
  syncError: string | null;
}
