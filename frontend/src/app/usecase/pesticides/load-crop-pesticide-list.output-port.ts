import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropPesticideListDataDto } from './load-crop-pesticide-list.dtos';

export interface LoadCropPesticideListOutputPort {
  present(dto: CropPesticideListDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_CROP_PESTICIDE_LIST_OUTPUT_PORT = new InjectionToken<LoadCropPesticideListOutputPort>(
  'LOAD_CROP_PESTICIDE_LIST_OUTPUT_PORT'
);
