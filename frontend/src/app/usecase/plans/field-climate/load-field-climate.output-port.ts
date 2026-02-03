import { InjectionToken } from '@angular/core';
import { FieldCultivationClimateData } from '../../../domain/plans/field-cultivation-climate-data';
import { ErrorDto } from '../../../domain/shared/error.dto';

export interface LoadFieldClimateOutputPort {
  present(dto: FieldCultivationClimateData): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_FIELD_CLIMATE_OUTPUT_PORT = new InjectionToken<LoadFieldClimateOutputPort>(
  'LOAD_FIELD_CLIMATE_OUTPUT_PORT'
);
