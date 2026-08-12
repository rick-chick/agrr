import { InjectionToken } from '@angular/core';
import { FieldClimatePresentationDto } from './load-field-climate.dtos';
import { ErrorDto } from '../../../domain/shared/error.dto';

export interface LoadFieldClimateOutputPort {
  present(dto: FieldClimatePresentationDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_FIELD_CLIMATE_OUTPUT_PORT = new InjectionToken<LoadFieldClimateOutputPort>(
  'LOAD_FIELD_CLIMATE_OUTPUT_PORT'
);
