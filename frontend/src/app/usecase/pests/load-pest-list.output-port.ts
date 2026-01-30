import { InjectionToken } from '@angular/core';
import { PestListDataDto } from './load-pest-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPestListOutputPort {
  present(dto: PestListDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PEST_LIST_OUTPUT_PORT = new InjectionToken<LoadPestListOutputPort>(
  'LOAD_PEST_LIST_OUTPUT_PORT'
);
