import { InjectionToken } from '@angular/core';
import { FarmDetailDataDto } from './load-farm-detail.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadFarmDetailOutputPort {
  present(dto: FarmDetailDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_FARM_DETAIL_OUTPUT_PORT = new InjectionToken<LoadFarmDetailOutputPort>(
  'LOAD_FARM_DETAIL_OUTPUT_PORT'
);
