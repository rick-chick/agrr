import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropEditPresenter } from '../../adapters/crops/crop-edit.presenter';
import { CROP_GATEWAY } from './crop-gateway';
import { LoadCropForEditUseCase } from './load-crop-for-edit.usecase';
import { LOAD_CROP_FOR_EDIT_OUTPUT_PORT } from './load-crop-for-edit.output-port';
import { UpdateCropUseCase } from './update-crop.usecase';
import { UPDATE_CROP_OUTPUT_PORT } from './update-crop.output-port';

/** Composition wiring for crop edit (adapters bound at usecase boundary). */
export const CROP_EDIT_PROVIDERS: readonly Provider[] = [
  CropEditPresenter,
  LoadCropForEditUseCase,
  UpdateCropUseCase,
  { provide: LOAD_CROP_FOR_EDIT_OUTPUT_PORT, useExisting: CropEditPresenter },
  { provide: UPDATE_CROP_OUTPUT_PORT, useExisting: CropEditPresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway }
];

export { CropEditPresenter } from '../../adapters/crops/crop-edit.presenter';
