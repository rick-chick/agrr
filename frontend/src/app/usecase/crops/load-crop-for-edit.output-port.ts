import { InjectionToken } from '@angular/core';
import { LoadCropForEditDataDto } from './load-crop-for-edit.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadCropForEditOutputPort {
  present(dto: LoadCropForEditDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_CROP_FOR_EDIT_OUTPUT_PORT = new InjectionToken<LoadCropForEditOutputPort>(
  'LOAD_CROP_FOR_EDIT_OUTPUT_PORT'
);
