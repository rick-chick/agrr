import { InjectionToken } from '@angular/core';
import { PesticideDetailDataDto } from './load-pesticide-detail.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPesticideDetailOutputPort {
  present(dto: PesticideDetailDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PESTICIDE_DETAIL_OUTPUT_PORT = new InjectionToken<LoadPesticideDetailOutputPort>(
  'LOAD_PESTICIDE_DETAIL_OUTPUT_PORT'
);