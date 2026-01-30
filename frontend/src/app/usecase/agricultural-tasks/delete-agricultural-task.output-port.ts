import { InjectionToken } from '@angular/core';
import { DeleteAgriculturalTaskSuccessDto } from './delete-agricultural-task.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DeleteAgriculturalTaskOutputPort {
  onSuccess(dto: DeleteAgriculturalTaskSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_AGRICULTURAL_TASK_OUTPUT_PORT = new InjectionToken<DeleteAgriculturalTaskOutputPort>(
  'DELETE_AGRICULTURAL_TASK_OUTPUT_PORT'
);