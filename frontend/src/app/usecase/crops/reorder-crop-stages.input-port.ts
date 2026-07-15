import { InjectionToken } from '@angular/core';
import { ReorderCropStagesInputPort } from './reorder-crop-stages.output-port';

export const REORDER_CROP_STAGES_INPUT_PORT = new InjectionToken<ReorderCropStagesInputPort>(
  'REORDER_CROP_STAGES_INPUT_PORT'
);
