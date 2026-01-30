import { InjectionToken } from '@angular/core';
import { CropDetailDataDto } from './load-crop-detail.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadCropDetailOutputPort {
  present(dto: CropDetailDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_CROP_DETAIL_OUTPUT_PORT = new InjectionToken<LoadCropDetailOutputPort>(
  'LOAD_CROP_DETAIL_OUTPUT_PORT'
);
