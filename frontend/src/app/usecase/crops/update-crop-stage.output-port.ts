import { InjectionToken } from '@angular/core';
import { UpdateCropStageOutputDto } from './update-crop-stage.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateCropStageOutputPort {
  present(dto: UpdateCropStageOutputDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_CROP_STAGE_OUTPUT_PORT = new InjectionToken<UpdateCropStageOutputPort>('UPDATE_CROP_STAGE_OUTPUT_PORT');