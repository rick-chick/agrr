import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropListPresenter } from '../../adapters/crops/crop-list.presenter';
import { CROP_GATEWAY } from './crop-gateway';
import { DeleteCropUseCase } from './delete-crop.usecase';
import { DELETE_CROP_OUTPUT_PORT } from './delete-crop.output-port';
import { LOAD_CROP_LIST_OUTPUT_PORT } from './load-crop-list.output-port';
import { LoadCropListUseCase } from './load-crop-list.usecase';

/** Composition wiring for crop list (adapters bound at usecase boundary). */
export const CROP_LIST_PROVIDERS: readonly Provider[] = [
  CropListPresenter,
  LoadCropListUseCase,
  DeleteCropUseCase,
  { provide: LOAD_CROP_LIST_OUTPUT_PORT, useExisting: CropListPresenter },
  { provide: DELETE_CROP_OUTPUT_PORT, useExisting: CropListPresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway }
];

export { CropListPresenter } from '../../adapters/crops/crop-list.presenter';
