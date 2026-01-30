import { InjectionToken } from '@angular/core';
import { DeleteFarmSuccessDto } from './delete-farm.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DeleteFarmOutputPort {
  onSuccess(dto: DeleteFarmSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_FARM_OUTPUT_PORT = new InjectionToken<DeleteFarmOutputPort>(
  'DELETE_FARM_OUTPUT_PORT'
);
