import { InjectionToken } from '@angular/core';
import { PesticideListDataDto } from './load-pesticide-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPesticideListOutputPort {
  present(dto: PesticideListDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PESTICIDE_LIST_OUTPUT_PORT = new InjectionToken<LoadPesticideListOutputPort>(
  'LOAD_PESTICIDE_LIST_OUTPUT_PORT'
);
