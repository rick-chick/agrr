import { Provider } from '@angular/core';
import { CropApiGateway } from '../../adapters/crops/crop-api.gateway';
import { PestApiGateway } from '../../adapters/pests/pest-api.gateway';
import { PesticideApiGateway } from '../../adapters/pesticides/pesticide-api.gateway';
import { PesticideDetailPresenter } from '../../adapters/pesticides/pesticide-detail.presenter';
import { DeletePesticideUseCase } from './delete-pesticide.usecase';
import { DELETE_PESTICIDE_OUTPUT_PORT } from './delete-pesticide.output-port';
import { CROP_GATEWAY } from '../crops/crop-gateway';
import { LOAD_PESTICIDE_DETAIL_OUTPUT_PORT } from './load-pesticide-detail.output-port';
import { LoadPesticideDetailUseCase } from './load-pesticide-detail.usecase';
import { PEST_GATEWAY } from '../pests/pest-gateway';
import { PESTICIDE_GATEWAY } from './pesticide-gateway';

export const PESTICIDE_DETAIL_PROVIDERS: readonly Provider[] = [
  PesticideDetailPresenter,
  LoadPesticideDetailUseCase,
  DeletePesticideUseCase,
  { provide: LOAD_PESTICIDE_DETAIL_OUTPUT_PORT, useExisting: PesticideDetailPresenter },
  { provide: DELETE_PESTICIDE_OUTPUT_PORT, useExisting: PesticideDetailPresenter },
  { provide: PESTICIDE_GATEWAY, useClass: PesticideApiGateway },
  { provide: CROP_GATEWAY, useClass: CropApiGateway },
  { provide: PEST_GATEWAY, useClass: PestApiGateway }
];

export { PesticideDetailPresenter } from '../../adapters/pesticides/pesticide-detail.presenter';
