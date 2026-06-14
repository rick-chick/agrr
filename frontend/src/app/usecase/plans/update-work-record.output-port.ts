import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import {
  UpdateWorkRecordSuccessDto,
  UpdateWorkRecordValidationErrorDto
} from './update-work-record.dtos';

export interface UpdateWorkRecordOutputPort {
  onSuccess(dto: UpdateWorkRecordSuccessDto): void;
  onValidationError(dto: UpdateWorkRecordValidationErrorDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_WORK_RECORD_OUTPUT_PORT = new InjectionToken<UpdateWorkRecordOutputPort>(
  'UPDATE_WORK_RECORD_OUTPUT_PORT'
);
