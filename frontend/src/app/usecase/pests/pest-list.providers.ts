import { Provider } from '@angular/core';
import { PestApiGateway } from '../../adapters/pests/pest-api.gateway';
import { PestListPresenter } from '../../adapters/pests/pest-list.presenter';
import { DeletePestUseCase } from './delete-pest.usecase';
import { DELETE_PEST_OUTPUT_PORT } from './delete-pest.output-port';
import { LOAD_PEST_LIST_OUTPUT_PORT } from './load-pest-list.output-port';
import { LoadPestListUseCase } from './load-pest-list.usecase';
import { PEST_GATEWAY } from './pest-gateway';

export const PEST_LIST_PROVIDERS: readonly Provider[] = [
  PestListPresenter,
  LoadPestListUseCase,
  DeletePestUseCase,
  { provide: LOAD_PEST_LIST_OUTPUT_PORT, useExisting: PestListPresenter },
  { provide: DELETE_PEST_OUTPUT_PORT, useExisting: PestListPresenter },
  { provide: PEST_GATEWAY, useClass: PestApiGateway }
];

export { PestListPresenter } from '../../adapters/pests/pest-list.presenter';
