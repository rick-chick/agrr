import { SubscribeTaskScheduleSyncInputDto } from './subscribe-task-schedule-sync.dtos';

export interface SubscribeTaskScheduleSyncInputPort {
  execute(dto: SubscribeTaskScheduleSyncInputDto): void;
}
