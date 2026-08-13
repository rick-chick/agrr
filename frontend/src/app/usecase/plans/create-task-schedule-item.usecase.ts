import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';
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
    @Inject(WORK_RECORD_GATEWAY) private readonly gateway: WorkRecordGateway
  ) {}

  execute(dto: CreateTaskScheduleItemInputDto): void {
    this.gateway.createTaskScheduleItem(dto.planId, dto.body).subscribe({
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
