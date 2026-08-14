import { InjectionToken } from '@angular/core';
import { PreviewWorkRowMiniClimateStateDto } from './preview-work-row-mini-climate.dtos';

export interface PreviewWorkRowMiniClimateOutputPort {
  presentMiniClimate(state: PreviewWorkRowMiniClimateStateDto): void;
}

export const PREVIEW_WORK_ROW_MINI_CLIMATE_OUTPUT_PORT =
  new InjectionToken<PreviewWorkRowMiniClimateOutputPort>(
    'PREVIEW_WORK_ROW_MINI_CLIMATE_OUTPUT_PORT'
  );
