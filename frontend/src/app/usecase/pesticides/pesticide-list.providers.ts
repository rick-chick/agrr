import { Provider } from '@angular/core';
import { PesticideApiGateway } from '../../adapters/pesticides/pesticide-api.gateway';
import { PesticideListPresenter } from '../../adapters/pesticides/pesticide-list.presenter';
import { DeletePesticideUseCase } from './delete-pesticide.usecase';
import { DELETE_PESTICIDE_OUTPUT_PORT } from './delete-pesticide.output-port';
import { LOAD_PESTICIDE_LIST_OUTPUT_PORT } from './load-pesticide-list.output-port';
import { LoadPesticideListUseCase } from './load-pesticide-list.usecase';
import { PESTICIDE_GATEWAY } from './pesticide-gateway';

export const PESTICIDE_LIST_PROVIDERS: readonly Provider[] = [
  PesticideListPresenter,
  LoadPesticideListUseCase,
  DeletePesticideUseCase,
  { provide: LOAD_PESTICIDE_LIST_OUTPUT_PORT, useExisting: PesticideListPresenter },
  { provide: DELETE_PESTICIDE_OUTPUT_PORT, useExisting: PesticideListPresenter },
  { provide: PESTICIDE_GATEWAY, useClass: PesticideApiGateway }
];

export { PesticideListPresenter } from '../../adapters/pesticides/pesticide-list.presenter';
