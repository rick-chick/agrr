import { InjectionToken } from '@angular/core';
import { PreviewWorkRecordClimateStateDto } from './preview-work-record-climate.dtos';

export interface PreviewWorkRecordClimateOutputPort {
  presentClimatePreview(dto: PreviewWorkRecordClimateStateDto): void;
}

export const PREVIEW_WORK_RECORD_CLIMATE_OUTPUT_PORT = new InjectionToken<PreviewWorkRecordClimateOutputPort>(
  'PREVIEW_WORK_RECORD_CLIMATE_OUTPUT_PORT'
);
