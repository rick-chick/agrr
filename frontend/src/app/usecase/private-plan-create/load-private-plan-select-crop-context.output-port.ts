import { InjectionToken } from '@angular/core';
import { PrivatePlanSelectCropContextDataDto } from './load-private-plan-select-crop-context.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadPrivatePlanSelectCropContextOutputPort {
  present(dto: PrivatePlanSelectCropContextDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_PRIVATE_PLAN_SELECT_CROP_CONTEXT_OUTPUT_PORT = new InjectionToken<LoadPrivatePlanSelectCropContextOutputPort>(
  'LOAD_PRIVATE_PLAN_SELECT_CROP_CONTEXT_OUTPUT_PORT'
);