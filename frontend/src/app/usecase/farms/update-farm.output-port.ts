import { InjectionToken } from '@angular/core';
import { UpdateFarmSuccessDto } from './update-farm.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateFarmOutputPort {
  onSuccess(dto: UpdateFarmSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_FARM_OUTPUT_PORT = new InjectionToken<UpdateFarmOutputPort>(
  'UPDATE_FARM_OUTPUT_PORT'
);
