import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { CropCreatePresenter } from '../../adapters/crops/crop-create.presenter';
import { CREATE_CROP_OUTPUT_PORT } from './create-crop.output-port';
import { CreateCropUseCase } from './create-crop.usecase';
import { CROP_GATEWAY } from './crop-gateway';

/** Composition wiring for crop create (adapters bound at usecase boundary). */
export const CROP_CREATE_PROVIDERS: readonly Provider[] = [
  CropCreatePresenter,
  CreateCropUseCase,
  { provide: CREATE_CROP_OUTPUT_PORT, useExisting: CropCreatePresenter },
  { provide: CROP_GATEWAY, useClass: CropApiGateway }
];

export { CropCreatePresenter } from '../../adapters/crops/crop-create.presenter';
