import { InjectionToken } from '@angular/core';
import { DeletePesticideSuccessDto } from './delete-pesticide.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DeletePesticideOutputPort {
  onSuccess(dto: DeletePesticideSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_PESTICIDE_OUTPUT_PORT = new InjectionToken<DeletePesticideOutputPort>(
  'DELETE_PESTICIDE_OUTPUT_PORT'
);