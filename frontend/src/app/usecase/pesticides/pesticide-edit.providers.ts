import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { PestApiGateway } from '../../adapters/pests/pest-api.gateway';
import { PesticideApiGateway } from '../../adapters/pesticides/pesticide-api.gateway';
import { PesticideEditPresenter } from '../../adapters/pesticides/pesticide-edit.presenter';
import { CROP_GATEWAY } from '../crops/crop-gateway';
import { LOAD_PESTICIDE_FOR_EDIT_OUTPUT_PORT } from './load-pesticide-for-edit.output-port';
import { LoadPesticideForEditUseCase } from './load-pesticide-for-edit.usecase';
import { PEST_GATEWAY } from '../pests/pest-gateway';
import { PESTICIDE_GATEWAY } from './pesticide-gateway';
import { UPDATE_PESTICIDE_OUTPUT_PORT } from './update-pesticide.output-port';
import { UpdatePesticideUseCase } from './update-pesticide.usecase';

export const PESTICIDE_EDIT_PROVIDERS: readonly Provider[] = [
  PesticideEditPresenter,
  LoadPesticideForEditUseCase,
  UpdatePesticideUseCase,
  { provide: LOAD_PESTICIDE_FOR_EDIT_OUTPUT_PORT, useExisting: PesticideEditPresenter },
  { provide: UPDATE_PESTICIDE_OUTPUT_PORT, useExisting: PesticideEditPresenter },
  { provide: PESTICIDE_GATEWAY, useClass: PesticideApiGateway },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: PEST_GATEWAY, useClass: PestApiGateway }
];

export { PesticideEditPresenter } from '../../adapters/pesticides/pesticide-edit.presenter';
