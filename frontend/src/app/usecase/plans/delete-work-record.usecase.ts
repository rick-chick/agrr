import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';
import { DeleteWorkRecordInputDto } from './delete-work-record.dtos';
import { DeleteWorkRecordInputPort } from './delete-work-record.input-port';
import {
  DELETE_WORK_RECORD_OUTPUT_PORT,
  DeleteWorkRecordOutputPort
} from './delete-work-record.output-port';

@Injectable()
export class DeleteWorkRecordUseCase implements DeleteWorkRecordInputPort {
  constructor(
    @Inject(DELETE_WORK_RECORD_OUTPUT_PORT) private readonly outputPort: DeleteWorkRecordOutputPort,
    @Inject(WORK_RECORD_GATEWAY) private readonly gateway: WorkRecordGateway
  ) {}

  execute(dto: DeleteWorkRecordInputDto): void {
    this.gateway.deleteWorkRecord(dto.planId, dto.workRecordId).subscribe({
      next: () => {
        this.outputPort.onDeleteSuccess();
        dto.onSuccess?.();
      },
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
