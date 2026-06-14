import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { LoadWorkRecordsDataDto } from './load-work-records.dtos';

export interface LoadWorkRecordsOutputPort {
  present(dto: LoadWorkRecordsDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_WORK_RECORDS_OUTPUT_PORT = new InjectionToken<LoadWorkRecordsOutputPort>(
  'LOAD_WORK_RECORDS_OUTPUT_PORT'
);
