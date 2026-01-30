import { InjectionToken } from '@angular/core';
import { FarmListDataDto } from './load-farm-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadFarmListOutputPort {
  present(dto: FarmListDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_FARM_LIST_OUTPUT_PORT = new InjectionToken<LoadFarmListOutputPort>(
  'LOAD_FARM_LIST_OUTPUT_PORT'
);
