import { InjectionToken } from '@angular/core';
import { UpdateCropSuccessDto } from './update-crop.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateCropOutputPort {
  onSuccess(dto: UpdateCropSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_CROP_OUTPUT_PORT = new InjectionToken<UpdateCropOutputPort>(
  'UPDATE_CROP_OUTPUT_PORT'
);
