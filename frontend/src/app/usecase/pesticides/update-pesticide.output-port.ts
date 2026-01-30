import { InjectionToken } from '@angular/core';
import { UpdatePesticideSuccessDto } from './update-pesticide.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdatePesticideOutputPort {
  onSuccess(dto: UpdatePesticideSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_PESTICIDE_OUTPUT_PORT = new InjectionToken<UpdatePesticideOutputPort>(
  'UPDATE_PESTICIDE_OUTPUT_PORT'
);