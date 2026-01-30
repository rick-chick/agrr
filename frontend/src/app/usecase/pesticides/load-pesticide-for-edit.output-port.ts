import { InjectionToken } from '@angular/core';
import { LoadPesticideForEditDataDto } from './load-pesticide-for-edit.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPesticideForEditOutputPort {
  present(dto: LoadPesticideForEditDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PESTICIDE_FOR_EDIT_OUTPUT_PORT = new InjectionToken<LoadPesticideForEditOutputPort>(
  'LOAD_PESTICIDE_FOR_EDIT_OUTPUT_PORT'
);