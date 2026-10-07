import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';
import { SkipTaskScheduleItemInputDto } from './skip-task-schedule-item.dtos';
import { SkipTaskScheduleItemInputPort } from './skip-task-schedule-item.input-port';
import {
  SKIP_TASK_SCHEDULE_ITEM_OUTPUT_PORT,
  SkipTaskScheduleItemOutputPort
} from './skip-task-schedule-item.output-port';

@Injectable()
export class SkipTaskScheduleItemUseCase implements SkipTaskScheduleItemInputPort {
  constructor(
    @Inject(SKIP_TASK_SCHEDULE_ITEM_OUTPUT_PORT) private readonly outputPort: SkipTaskScheduleItemOutputPort,
    @Inject(WORK_RECORD_GATEWAY) private readonly gateway: WorkRecordGateway
  ) {}

  execute(dto: SkipTaskScheduleItemInputDto): void {
    const request$ = dto.skip
      ? this.gateway.skipTaskScheduleItem(dto.planId, dto.itemId)
      : this.gateway.unskipTaskScheduleItem(dto.planId, dto.itemId);

    request$.subscribe({
      next: () => {
        this.outputPort.onSuccess();
        dto.onSuccess?.();
      },
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
