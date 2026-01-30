import { InjectionToken } from '@angular/core';
import { DeleteCropSuccessDto } from './delete-crop.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DeleteCropOutputPort {
  onSuccess(dto: DeleteCropSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_CROP_OUTPUT_PORT = new InjectionToken<DeleteCropOutputPort>(
  'DELETE_CROP_OUTPUT_PORT'
);
