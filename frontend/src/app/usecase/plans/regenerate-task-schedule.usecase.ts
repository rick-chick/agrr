import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import { RegenerateTaskScheduleInputDto } from './regenerate-task-schedule.dtos';
import { RegenerateTaskScheduleInputPort } from './regenerate-task-schedule.input-port';
import {
  REGENERATE_TASK_SCHEDULE_OUTPUT_PORT,
  RegenerateTaskScheduleOutputPort
} from './regenerate-task-schedule.output-port';

@Injectable()
export class RegenerateTaskScheduleUseCase implements RegenerateTaskScheduleInputPort {
  constructor(
    @Inject(REGENERATE_TASK_SCHEDULE_OUTPUT_PORT) private readonly outputPort: RegenerateTaskScheduleOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: RegenerateTaskScheduleInputDto): void {
    this.outputPort.onRegenerateStarted();
    this.planGateway.regenerateTaskSchedule(dto.planId).subscribe({
      next: () => this.outputPort.onRegenerateSuccess(),
      error: (err: unknown) => this.outputPort.onRegenerateError({ message: apiErrorI18nKey(err) })
    });
  }
}
