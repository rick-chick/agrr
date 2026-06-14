import { HttpErrorResponse } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';
import { UpdateWorkRecordInputDto } from './update-work-record.dtos';
import { UpdateWorkRecordInputPort } from './update-work-record.input-port';
import {
  UPDATE_WORK_RECORD_OUTPUT_PORT,
  UpdateWorkRecordOutputPort
} from './update-work-record.output-port';

type ValidationErrorBody = {
  errors?: Record<string, string[]>;
};

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
        if (err instanceof HttpErrorResponse && err.status === 422) {
          const body = err.error as ValidationErrorBody | null;
          if (body?.errors && Object.keys(body.errors).length > 0) {
            this.outputPort.onValidationError({ fieldErrors: body.errors });
            return;
          }
        }
        this.outputPort.onError({ message: apiErrorI18nKey(err) });
      }
    });
  }
}
