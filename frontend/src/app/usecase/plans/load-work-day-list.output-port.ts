import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { LoadWorkDayListDataDto } from './load-work-day-list.dtos';

export interface LoadWorkDayListOutputPort {
  present(dto: LoadWorkDayListDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_WORK_DAY_LIST_OUTPUT_PORT = new InjectionToken<LoadWorkDayListOutputPort>(
  'LOAD_WORK_DAY_LIST_OUTPUT_PORT'
);
