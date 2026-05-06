import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { PestApiGateway } from '../../adapters/pests/pest-api.gateway';
import { PesticideApiGateway } from '../../adapters/pesticides/pesticide-api.gateway';
import { PesticideCreatePresenter } from '../../adapters/pesticides/pesticide-create.presenter';
import { CREATE_PESTICIDE_OUTPUT_PORT } from './create-pesticide.output-port';
import { CreatePesticideUseCase } from './create-pesticide.usecase';
import { CROP_GATEWAY } from '../crops/crop-gateway';
import { PEST_GATEWAY } from '../pests/pest-gateway';
import { PESTICIDE_GATEWAY } from './pesticide-gateway';

export const PESTICIDE_CREATE_PROVIDERS: readonly Provider[] = [
  PesticideCreatePresenter,
  CreatePesticideUseCase,
  { provide: CREATE_PESTICIDE_OUTPUT_PORT, useExisting: PesticideCreatePresenter },
  { provide: PESTICIDE_GATEWAY, useClass: PesticideApiGateway },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: PEST_GATEWAY, useClass: PestApiGateway }
];

export { PesticideCreatePresenter } from '../../adapters/pesticides/pesticide-create.presenter';
