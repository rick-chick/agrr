import { InjectionToken } from '@angular/core';
import { ReorderCropStagesOutputDto } from './reorder-crop-stages.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface ReorderCropStagesOutputPort {
  present(dto: ReorderCropStagesOutputDto): void;
  onError(dto: ErrorDto): void;
}

export const REORDER_CROP_STAGES_OUTPUT_PORT = new InjectionToken<ReorderCropStagesOutputPort>(
  'REORDER_CROP_STAGES_OUTPUT_PORT'
);
