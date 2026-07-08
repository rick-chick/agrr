import { Inject, Injectable } from '@angular/core';
import { LoadPlanTaskScheduleInputDto } from './load-plan-task-schedule.dtos';
import { LoadPlanTaskScheduleInputPort } from './load-plan-task-schedule.input-port';
import {
  LoadPlanTaskScheduleOutputPort,
  LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT
} from './load-plan-task-schedule.output-port';
import { PLAN_GATEWAY, PlanGateway, TaskScheduleQueryOptions } from './plan-gateway';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';

@Injectable()
export class LoadPlanTaskScheduleUseCase implements LoadPlanTaskScheduleInputPort {
  constructor(
    @Inject(LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT) private readonly outputPort: LoadPlanTaskScheduleOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: LoadPlanTaskScheduleInputDto): void {
    const options: TaskScheduleQueryOptions = { scope: dto.scope ?? 'plan' };
    if (dto.weekStart) {
      options.weekStart = dto.weekStart;
    }
    if (dto.fieldCultivationId != null) {
      options.fieldCultivationId = dto.fieldCultivationId;
    }
    this.planGateway.getTaskSchedule(dto.planId, options).subscribe({
      next: (schedule) => this.outputPort.present({ schedule }),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
