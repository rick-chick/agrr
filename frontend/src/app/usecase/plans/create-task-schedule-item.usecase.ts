import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import { CreateTaskScheduleItemInputDto } from './create-task-schedule-item.dtos';
import { CreateTaskScheduleItemInputPort } from './create-task-schedule-item.input-port';
import {
  CREATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT,
  CreateTaskScheduleItemOutputPort
} from './create-task-schedule-item.output-port';

@Injectable()
export class CreateTaskScheduleItemUseCase implements CreateTaskScheduleItemInputPort {
  constructor(
    @Inject(CREATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT) private readonly outputPort: CreateTaskScheduleItemOutputPort,
    @Inject(PLAN_GATEWAY) private readonly gateway: PlanGateway
  ) {}

  execute(dto: CreateTaskScheduleItemInputDto): void {
    this.gateway
      .createTaskScheduleItem(dto.planId, {
        field_cultivation_id: dto.fieldCultivationId,
        name: dto.name,
        scheduled_date: dto.scheduledDate,
        agricultural_task_id: dto.agriculturalTaskId ?? undefined
      })
      .subscribe({
        next: () => {
          this.outputPort.onSuccess();
          dto.onSuccess?.();
        },
        error: (err: unknown) => {
          dto.onError?.();
          this.outputPort.onError({ message: apiErrorI18nKey(err) });
        }
      });
  }
}
