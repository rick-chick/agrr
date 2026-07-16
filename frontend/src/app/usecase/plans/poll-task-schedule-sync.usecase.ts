import { Inject, Injectable } from '@angular/core';
import { Subscription, timer } from 'rxjs';
import { last, map, switchMap, take, takeWhile } from 'rxjs/operators';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import {
  SUBSCRIBE_TASK_SCHEDULE_SYNC_OUTPUT_PORT,
  SubscribeTaskScheduleSyncOutputPort
} from './subscribe-task-schedule-sync.output-port';
import {
  isTaskScheduleSyncPollable,
  TASK_SCHEDULE_SYNC_POLL_INTERVAL_MS,
  TASK_SCHEDULE_SYNC_POLL_MAX_ATTEMPTS
} from './task-schedule-sync-lifecycle';
import { PollTaskScheduleSyncInputDto } from './poll-task-schedule-sync.dtos';

@Injectable()
export class PollTaskScheduleSyncUseCase {
  constructor(
    @Inject(SUBSCRIBE_TASK_SCHEDULE_SYNC_OUTPUT_PORT)
    private readonly outputPort: SubscribeTaskScheduleSyncOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: PollTaskScheduleSyncInputDto): Subscription {
    return timer(0, TASK_SCHEDULE_SYNC_POLL_INTERVAL_MS)
      .pipe(
        take(TASK_SCHEDULE_SYNC_POLL_MAX_ATTEMPTS),
        switchMap(() => this.planGateway.getTaskSchedule(dto.planId)),
        takeWhile(
          (schedule) => isTaskScheduleSyncPollable(schedule.plan.task_schedule_sync_state),
          true
        ),
        last(),
        map((schedule) => ({
          syncState: schedule.plan.task_schedule_sync_state,
          syncError: schedule.plan.task_schedule_sync_error,
          syncErrorCropId: schedule.plan.task_schedule_sync_error_crop_id
        }))
      )
      .subscribe((message) => {
        if (!isTaskScheduleSyncPollable(message.syncState)) {
          this.outputPort.onTaskScheduleSync(message);
        }
      });
  }
}
