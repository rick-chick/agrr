import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import {
  SaveCropStageAdvancedDetailsPartialFailureDto,
  SaveCropStageAdvancedDetailsSuccessDto
} from './save-crop-stage-advanced-details.dtos';

export interface SaveCropStageAdvancedDetailsOutputPort {
  onSuccess(dto: SaveCropStageAdvancedDetailsSuccessDto): void;
  onAdvancedPartialFailure(dto: SaveCropStageAdvancedDetailsPartialFailureDto): void;
  onError(dto: ErrorDto): void;
}

export const SAVE_CROP_STAGE_ADVANCED_DETAILS_OUTPUT_PORT = new InjectionToken<SaveCropStageAdvancedDetailsOutputPort>(
  'SAVE_CROP_STAGE_ADVANCED_DETAILS_OUTPUT_PORT'
);
