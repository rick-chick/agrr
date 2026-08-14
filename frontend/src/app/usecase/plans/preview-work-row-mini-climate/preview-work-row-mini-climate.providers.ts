import { Provider } from '@angular/core';
import { FieldClimateApiGateway } from '../../../adapters/plans/field-climate-api.gateway';
import { PlanWorkMiniClimatePanelPresenter } from '../../../adapters/plans/plan-work-mini-climate-panel.presenter';
import { FIELD_CLIMATE_GATEWAY } from '../field-climate/field-climate.gateway';
import { PreviewWorkRowMiniClimateUseCase } from './preview-work-row-mini-climate.usecase';
import { PREVIEW_WORK_ROW_MINI_CLIMATE_OUTPUT_PORT } from './preview-work-row-mini-climate.output-port';

export const PREVIEW_WORK_ROW_MINI_CLIMATE_PROVIDERS: readonly Provider[] = [
  PlanWorkMiniClimatePanelPresenter,
  PreviewWorkRowMiniClimateUseCase,
  {
    provide: PREVIEW_WORK_ROW_MINI_CLIMATE_OUTPUT_PORT,
    useExisting: PlanWorkMiniClimatePanelPresenter
  },
  { provide: FIELD_CLIMATE_GATEWAY, useClass: FieldClimateApiGateway }
];
