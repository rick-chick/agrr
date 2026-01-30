import { InjectionToken } from '@angular/core';
import { CreatePesticideSuccessDto } from './create-pesticide.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreatePesticideOutputPort {
  onSuccess(dto: CreatePesticideSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_PESTICIDE_OUTPUT_PORT = new InjectionToken<CreatePesticideOutputPort>(
  'CREATE_PESTICIDE_OUTPUT_PORT'
);