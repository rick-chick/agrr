import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import { UpdateTaskScheduleItemInputDto } from './update-task-schedule-item.dtos';
import { UpdateTaskScheduleItemInputPort } from './update-task-schedule-item.input-port';
import {
  UPDATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT,
  UpdateTaskScheduleItemOutputPort
} from './update-task-schedule-item.output-port';

@Injectable()
export class UpdateTaskScheduleItemUseCase implements UpdateTaskScheduleItemInputPort {
  constructor(
    @Inject(UPDATE_TASK_SCHEDULE_ITEM_OUTPUT_PORT) private readonly outputPort: UpdateTaskScheduleItemOutputPort,
    @Inject(PLAN_GATEWAY) private readonly gateway: PlanGateway
  ) {}

  execute(dto: UpdateTaskScheduleItemInputDto): void {
    this.gateway
      .updateTaskScheduleItem(dto.planId, dto.itemId, { scheduled_date: dto.scheduledDate })
      .subscribe({
        next: () => {
          this.outputPort.onSuccess();
          dto.onSuccess?.();
        },
        error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
      });
  }
}
