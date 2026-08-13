import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';
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
    @Inject(WORK_RECORD_GATEWAY) private readonly gateway: WorkRecordGateway
  ) {}

  execute(dto: UpdateTaskScheduleItemInputDto): void {
    this.gateway.updateTaskScheduleItem(dto.planId, dto.itemId, dto.body).subscribe({
      next: () => {
        this.outputPort.onMutationSuccess();
        dto.onSuccess?.();
      },
      error: (err: unknown) => {
        const message = apiErrorI18nKey(err);
        this.outputPort.onMutationError({ message });
        dto.onError?.({ message });
      }
    });
  }
}
