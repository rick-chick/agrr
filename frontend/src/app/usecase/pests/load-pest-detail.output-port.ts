import { InjectionToken } from '@angular/core';
import { PestDetailDataDto } from './load-pest-detail.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPestDetailOutputPort {
  present(dto: PestDetailDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PEST_DETAIL_OUTPUT_PORT = new InjectionToken<LoadPestDetailOutputPort>(
  'LOAD_PEST_DETAIL_OUTPUT_PORT'
);