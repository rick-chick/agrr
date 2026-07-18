import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropListStagesPanelPresenter } from '../../adapters/crops/crop-list-stages-panel.presenter';
import { CROP_GATEWAY } from './crop-gateway';
import { LoadCropForEditUseCase } from './load-crop-for-edit.usecase';
import { LOAD_CROP_FOR_EDIT_OUTPUT_PORT } from './load-crop-for-edit.output-port';

export const CROP_LIST_STAGES_PANEL_PROVIDERS: readonly Provider[] = [
  CropListStagesPanelPresenter,
  LoadCropForEditUseCase,
  { provide: LOAD_CROP_FOR_EDIT_OUTPUT_PORT, useExisting: CropListStagesPanelPresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway }
];

export { CropListStagesPanelPresenter } from '../../adapters/crops/crop-list-stages-panel.presenter';
