import { InjectionToken } from '@angular/core';
import { LoadAgriculturalTaskDetailDataDto } from './load-agricultural-task-detail.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadAgriculturalTaskDetailOutputPort {
  present(dto: LoadAgriculturalTaskDetailDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_AGRICULTURAL_TASK_DETAIL_OUTPUT_PORT = new InjectionToken<LoadAgriculturalTaskDetailOutputPort>(
  'LOAD_AGRICULTURAL_TASK_DETAIL_OUTPUT_PORT'
);