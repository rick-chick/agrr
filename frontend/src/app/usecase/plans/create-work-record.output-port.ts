import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import {
  CreateWorkRecordSuccessDto,
  CreateWorkRecordValidationErrorDto
} from './create-work-record.dtos';

export interface CreateWorkRecordOutputPort {
  onSuccess(dto: CreateWorkRecordSuccessDto): void;
  onValidationError(dto: CreateWorkRecordValidationErrorDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_WORK_RECORD_OUTPUT_PORT = new InjectionToken<CreateWorkRecordOutputPort>(
  'CREATE_WORK_RECORD_OUTPUT_PORT'
);
