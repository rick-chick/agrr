import { InjectionToken } from '@angular/core';
import { FertilizeListDataDto } from './load-fertilize-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadFertilizeListOutputPort {
  present(dto: FertilizeListDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_FERTILIZE_LIST_OUTPUT_PORT = new InjectionToken<LoadFertilizeListOutputPort>(
  'LOAD_FERTILIZE_LIST_OUTPUT_PORT'
);
