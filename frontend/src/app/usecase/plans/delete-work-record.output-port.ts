import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { DeleteWorkRecordSuccessDto } from './delete-work-record.dtos';

export interface DeleteWorkRecordOutputPort {
  onDeleteSuccess(dto: DeleteWorkRecordSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_WORK_RECORD_OUTPUT_PORT = new InjectionToken<DeleteWorkRecordOutputPort>(
  'DELETE_WORK_RECORD_OUTPUT_PORT'
);
