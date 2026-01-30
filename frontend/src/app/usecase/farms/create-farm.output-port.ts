import { InjectionToken } from '@angular/core';
import { CreateFarmSuccessDto } from './create-farm.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreateFarmOutputPort {
  onSuccess(dto: CreateFarmSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_FARM_OUTPUT_PORT = new InjectionToken<CreateFarmOutputPort>(
  'CREATE_FARM_OUTPUT_PORT'
);
