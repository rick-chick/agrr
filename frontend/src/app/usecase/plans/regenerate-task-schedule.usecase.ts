import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { RegenerateTaskScheduleInputDto } from './regenerate-task-schedule.dtos';
import { RegenerateTaskScheduleInputPort } from './regenerate-task-schedule.input-port';
import {
  REGENERATE_TASK_SCHEDULE_OUTPUT_PORT,
  RegenerateTaskScheduleOutputPort
} from './regenerate-task-schedule.output-port';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import { PollTaskScheduleSyncUseCase } from './poll-task-schedule-sync.usecase';
import { isTaskScheduleSyncPollable } from './task-schedule-sync-lifecycle';

@Injectable()
export class RegenerateTaskScheduleUseCase implements RegenerateTaskScheduleInputPort {
  constructor(
    @Inject(REGENERATE_TASK_SCHEDULE_OUTPUT_PORT) private readonly outputPort: RegenerateTaskScheduleOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway,
    private readonly pollTaskScheduleSyncUseCase: PollTaskScheduleSyncUseCase
  ) {}

  execute(dto: RegenerateTaskScheduleInputDto): void {
    this.outputPort.onRegenerateStarted();
    this.planGateway.regenerateTaskSchedule(dto.planId).subscribe({
      next: (response) => {
        this.outputPort.onRegenerateSuccess(response);
        if (isTaskScheduleSyncPollable(response.task_schedule_sync_state)) {
          this.pollTaskScheduleSyncUseCase.execute({ planId: dto.planId });
        }
      },
      error: (err: unknown) => this.outputPort.onRegenerateError({ message: apiErrorI18nKey(err) })
    });
  }
}
