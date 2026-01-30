import { InjectionToken } from '@angular/core';
import { DeletePestSuccessDto } from './delete-pest.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DeletePestOutputPort {
  onSuccess(dto: DeletePestSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_PEST_OUTPUT_PORT = new InjectionToken<DeletePestOutputPort>(
  'DELETE_PEST_OUTPUT_PORT'
);