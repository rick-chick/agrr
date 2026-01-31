import { InjectionToken } from '@angular/core';
import { DeleteCropStageOutputDto } from './delete-crop-stage.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DeleteCropStageOutputPort {
  present(dto: DeleteCropStageOutputDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_CROP_STAGE_OUTPUT_PORT = new InjectionToken<DeleteCropStageOutputPort>('DELETE_CROP_STAGE_OUTPUT_PORT');