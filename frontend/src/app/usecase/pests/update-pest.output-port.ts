import { InjectionToken } from '@angular/core';
import { UpdatePestSuccessDto } from './update-pest.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdatePestOutputPort {
  onSuccess(dto: UpdatePestSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_PEST_OUTPUT_PORT = new InjectionToken<UpdatePestOutputPort>(
  'UPDATE_PEST_OUTPUT_PORT'
);