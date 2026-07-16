import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import {
  SaveCropStagePanelPartialFailureDto,
  SaveCropStagePanelSuccessDto
} from './save-crop-stage-panel.dtos';

export interface SaveCropStagePanelOutputPort {
  onSuccess(dto: SaveCropStagePanelSuccessDto): void;
  onPanelPartialFailure(dto: SaveCropStagePanelPartialFailureDto): void;
  onError(dto: ErrorDto): void;
}

export const SAVE_CROP_STAGE_PANEL_OUTPUT_PORT = new InjectionToken<SaveCropStagePanelOutputPort>(
  'SAVE_CROP_STAGE_PANEL_OUTPUT_PORT'
);
