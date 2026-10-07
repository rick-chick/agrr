import { Inject, Injectable } from '@angular/core';
import { apiErrorMessage, apiValidationFieldErrors } from '../../core/api-error-message';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';
import { CreateWorkRecordInputDto } from './create-work-record.dtos';
import { CreateWorkRecordInputPort } from './create-work-record.input-port';
import {
  CREATE_WORK_RECORD_OUTPUT_PORT,
  CreateWorkRecordOutputPort
} from './create-work-record.output-port';

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