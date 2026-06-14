import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DeleteWorkRecordOutputPort {
  onDeleteSuccess(): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_WORK_RECORD_OUTPUT_PORT = new InjectionToken<DeleteWorkRecordOutputPort>(
  'DELETE_WORK_RECORD_OUTPUT_PORT'
);
