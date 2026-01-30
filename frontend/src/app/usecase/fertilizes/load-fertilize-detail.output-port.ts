import { InjectionToken } from '@angular/core';
import { FertilizeDetailDataDto } from './load-fertilize-detail.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadFertilizeDetailOutputPort {
  present(dto: FertilizeDetailDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_FERTILIZE_DETAIL_OUTPUT_PORT = new InjectionToken<LoadFertilizeDetailOutputPort>(
  'LOAD_FERTILIZE_DETAIL_OUTPUT_PORT'
);
