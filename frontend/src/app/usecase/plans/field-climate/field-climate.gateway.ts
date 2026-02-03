import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { FieldCultivationClimateData } from '../../../domain/plans/field-cultivation-climate-data';
import { FetchFieldClimateDataRequestDto } from './load-field-climate.dtos';

export interface FieldClimateGateway {
  fetchFieldClimateData(dto: FetchFieldClimateDataRequestDto): Observable<FieldCultivationClimateData>;
}

export const FIELD_CLIMATE_GATEWAY = new InjectionToken<FieldClimateGateway>('FIELD_CLIMATE_GATEWAY');
