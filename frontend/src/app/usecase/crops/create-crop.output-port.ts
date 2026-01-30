import { InjectionToken } from '@angular/core';
import { CreateCropSuccessDto } from './create-crop.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreateCropOutputPort {
  onSuccess(dto: CreateCropSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_CROP_OUTPUT_PORT = new InjectionToken<CreateCropOutputPort>(
  'CREATE_CROP_OUTPUT_PORT'
);
