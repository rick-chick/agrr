import { InjectionToken } from '@angular/core';
import { DeletePlanSuccessDto } from './delete-plan.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DeletePlanOutputPort {
  onSuccess(dto: DeletePlanSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_PLAN_OUTPUT_PORT = new InjectionToken<DeletePlanOutputPort>(
  'DELETE_PLAN_OUTPUT_PORT'
);
