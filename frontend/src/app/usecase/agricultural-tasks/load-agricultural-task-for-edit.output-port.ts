import { InjectionToken } from '@angular/core';
import { LoadAgriculturalTaskForEditDataDto } from './load-agricultural-task-for-edit.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadAgriculturalTaskForEditOutputPort {
  present(dto: LoadAgriculturalTaskForEditDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_AGRICULTURAL_TASK_FOR_EDIT_OUTPUT_PORT = new InjectionToken<LoadAgriculturalTaskForEditOutputPort>(
  'LOAD_AGRICULTURAL_TASK_FOR_EDIT_OUTPUT_PORT'
);