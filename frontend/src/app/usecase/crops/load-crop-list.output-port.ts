import { InjectionToken } from '@angular/core';
import { CropListDataDto } from './load-crop-list.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadCropListOutputPort {
  present(dto: CropListDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_CROP_LIST_OUTPUT_PORT = new InjectionToken<LoadCropListOutputPort>(
  'LOAD_CROP_LIST_OUTPUT_PORT'
);
