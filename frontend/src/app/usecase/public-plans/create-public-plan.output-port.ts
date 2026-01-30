import { InjectionToken } from '@angular/core';
import { CreatePublicPlanResponse } from './public-plan-gateway';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreatePublicPlanOutputPort {
  onSuccess(dto: CreatePublicPlanResponse): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_PUBLIC_PLAN_OUTPUT_PORT = new InjectionToken<CreatePublicPlanOutputPort>(
  'CREATE_PUBLIC_PLAN_OUTPUT_PORT'
);
