import { Inject, Injectable } from '@angular/core';
import { apiErrorMessage, apiValidationFieldErrors } from '../../core/api-error-message';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';
import { UpdateWorkRecordInputDto } from './update-work-record.dtos';
import { UpdateWorkRecordInputPort } from './update-work-record.input-port';
import {
  UPDATE_WORK_RECORD_OUTPUT_PORT,
  UpdateWorkRecordOutputPort
} from './update-work-record.output-port';

@Injectable()
export class UpdateWorkRecordUseCase implements UpdateWorkRecordInputPort {
  constructor(
    @Inject(UPDATE_WORK_RECORD_OUTPUT_PORT) private readonly outputPort: UpdateWorkRecordOutputPort,
    @Inject(WORK_RECORD_GATEWAY) private readonly gateway: WorkRecordGateway
  ) {}

  execute(dto: UpdateWorkRecordInputDto): void {
    this.gateway.updateWorkRecord(dto.planId, dto.workRecordId, dto.body).subscribe({
      next: (response) => {
        this.outputPort.onSuccess({ workRecord: response.work_record });
        dto.onSuccess?.();
      },
      error: (err: unknown) => {
        const fieldErrors = apiValidationFieldErrors(err);
        if (fieldErrors) {
          this.outputPort.onValidationError({ fieldErrors });
          return;
        }
        this.outputPort.onError({ message: apiErrorMessage(err) });
      }
    });
  }
}