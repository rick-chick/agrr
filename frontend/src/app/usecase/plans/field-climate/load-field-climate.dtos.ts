import { FieldCultivationClimateData } from '../../../domain/plans/field-cultivation-climate-data';
import {
  FieldClimateLatestImplementation,
  FieldClimateWorkDayMarker
} from '../../../domain/plans/field-climate-work-records';

export interface LoadFieldClimateInputDto {
  fieldCultivationId: number;
  planType: 'private' | 'public' | 'demo';
  planId?: number | null;
  displayStartDate?: string | null;
  displayEndDate?: string | null;
}

export interface FetchFieldClimateDataRequestDto {
  fieldCultivationId: number;
  planType: 'private' | 'public' | 'demo';
  displayStartDate?: string | null;
  displayEndDate?: string | null;
}

export type FieldClimatePresentationDto = {
  climateData: FieldCultivationClimateData;
  workDayMarkers: FieldClimateWorkDayMarker[];
  latestImplementation: FieldClimateLatestImplementation | null;
};
