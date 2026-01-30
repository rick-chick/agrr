import { InjectionToken } from '@angular/core';
import { LoadPestForEditDataDto } from './load-pest-for-edit.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPestForEditOutputPort {
  present(dto: LoadPestForEditDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PEST_FOR_EDIT_OUTPUT_PORT = new InjectionToken<LoadPestForEditOutputPort>(
  'LOAD_PEST_FOR_EDIT_OUTPUT_PORT'
);