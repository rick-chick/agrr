import { InjectionToken } from '@angular/core';
import { AgriculturalTaskListDataDto } from './load-agricultural-task-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadAgriculturalTaskListOutputPort {
  present(dto: AgriculturalTaskListDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT =
  new InjectionToken<LoadAgriculturalTaskListOutputPort>(
    'LOAD_AGRICULTURAL_TASK_LIST_OUTPUT_PORT'
  );
