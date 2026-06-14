import { HttpErrorResponse } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';
import { CreateWorkRecordInputDto } from './create-work-record.dtos';
import { CreateWorkRecordInputPort } from './create-work-record.input-port';
import {
  CREATE_WORK_RECORD_OUTPUT_PORT,
  CreateWorkRecordOutputPort
} from './create-work-record.output-port';

type ValidationErrorBody = {
  errors?: Record<string, string[]>;
};

@Injectable()
export class CreateWorkRecordUseCase implements CreateWorkRecordInputPort {
  constructor(
    @Inject(CREATE_WORK_RECORD_OUTPUT_PORT) private readonly outputPort: CreateWorkRecordOutputPort,
    @Inject(WORK_RECORD_GATEWAY) private readonly gateway: WorkRecordGateway
  ) {}

  execute(dto: CreateWorkRecordInputDto): void {
    this.gateway.createWorkRecord(dto.planId, dto.body).subscribe({
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
