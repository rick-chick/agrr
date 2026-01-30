import { InjectionToken } from '@angular/core';
import { LoadFertilizeForEditDataDto } from './load-fertilize-for-edit.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadFertilizeForEditOutputPort {
  present(dto: LoadFertilizeForEditDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_FERTILIZE_FOR_EDIT_OUTPUT_PORT = new InjectionToken<LoadFertilizeForEditOutputPort>(
  'LOAD_FERTILIZE_FOR_EDIT_OUTPUT_PORT'
);
