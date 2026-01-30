import { InjectionToken } from '@angular/core';
import { CreatePestSuccessDto } from './create-pest.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreatePestOutputPort {
  onSuccess(dto: CreatePestSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_PEST_OUTPUT_PORT = new InjectionToken<CreatePestOutputPort>(
  'CREATE_PEST_OUTPUT_PORT'
);