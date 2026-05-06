import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropDetailPresenter } from '../../adapters/crops/crop-detail.presenter';
import { CROP_GATEWAY } from './crop-gateway';
import { DeleteCropUseCase } from './delete-crop.usecase';
import { DELETE_CROP_OUTPUT_PORT } from './delete-crop.output-port';
import { LOAD_CROP_DETAIL_OUTPUT_PORT } from './load-crop-detail.output-port';
import { LoadCropDetailUseCase } from './load-crop-detail.usecase';

/** Composition wiring for crop detail (adapters bound at usecase boundary). */
export const CROP_DETAIL_PROVIDERS: readonly Provider[] = [
  CropDetailPresenter,
  LoadCropDetailUseCase,
  DeleteCropUseCase,
  { provide: LOAD_CROP_DETAIL_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: DELETE_CROP_OUTPUT_PORT, useExisting: CropDetailPresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway }
];

export { CropDetailPresenter } from '../../adapters/crops/crop-detail.presenter';
