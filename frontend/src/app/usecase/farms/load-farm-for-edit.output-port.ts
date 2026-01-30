import { InjectionToken } from '@angular/core';
import { LoadFarmForEditDataDto } from './load-farm-for-edit.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadFarmForEditOutputPort {
  present(dto: LoadFarmForEditDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_FARM_FOR_EDIT_OUTPUT_PORT = new InjectionToken<LoadFarmForEditOutputPort>(
  'LOAD_FARM_FOR_EDIT_OUTPUT_PORT'
);
