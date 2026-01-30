import { InjectionToken } from '@angular/core';
import { CreateAgriculturalTaskSuccessDto } from './create-agricultural-task.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreateAgriculturalTaskOutputPort {
  onSuccess(dto: CreateAgriculturalTaskSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_AGRICULTURAL_TASK_OUTPUT_PORT = new InjectionToken<CreateAgriculturalTaskOutputPort>(
  'CREATE_AGRICULTURAL_TASK_OUTPUT_PORT'
);