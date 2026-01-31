import { InjectionToken } from '@angular/core';
import { CreateCropStageOutputDto } from './create-crop-stage.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreateCropStageOutputPort {
  present(dto: CreateCropStageOutputDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_CROP_STAGE_OUTPUT_PORT = new InjectionToken<CreateCropStageOutputPort>('CREATE_CROP_STAGE_OUTPUT_PORT');