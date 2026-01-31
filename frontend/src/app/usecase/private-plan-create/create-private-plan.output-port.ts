import { InjectionToken } from '@angular/core';
import { CreatePrivatePlanResponseDto } from './create-private-plan.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreatePrivatePlanOutputPort {
  present(dto: CreatePrivatePlanResponseDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_PRIVATE_PLAN_OUTPUT_PORT = new InjectionToken<CreatePrivatePlanOutputPort>(
  'CREATE_PRIVATE_PLAN_OUTPUT_PORT'
);