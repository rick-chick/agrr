import { InjectionToken } from '@angular/core';
import { UpdateAgriculturalTaskSuccessDto } from './update-agricultural-task.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateAgriculturalTaskOutputPort {
  onSuccess(dto: UpdateAgriculturalTaskSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_AGRICULTURAL_TASK_OUTPUT_PORT = new InjectionToken<UpdateAgriculturalTaskOutputPort>(
  'UPDATE_AGRICULTURAL_TASK_OUTPUT_PORT'
);