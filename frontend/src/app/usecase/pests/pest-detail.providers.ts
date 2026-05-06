import { Provider } from '@angular/core';
import { PestApiGateway } from '../../adapters/pests/pest-api.gateway';
import { PestDetailPresenter } from '../../adapters/pests/pest-detail.presenter';
import { DeletePestUseCase } from './delete-pest.usecase';
import { DELETE_PEST_OUTPUT_PORT } from './delete-pest.output-port';
import { LOAD_PEST_DETAIL_OUTPUT_PORT } from './load-pest-detail.output-port';
import { LoadPestDetailUseCase } from './load-pest-detail.usecase';
import { PEST_GATEWAY } from './pest-gateway';

export const PEST_DETAIL_PROVIDERS: readonly Provider[] = [
  PestDetailPresenter,
  LoadPestDetailUseCase,
  DeletePestUseCase,
  { provide: LOAD_PEST_DETAIL_OUTPUT_PORT, useExisting: PestDetailPresenter },
  { provide: DELETE_PEST_OUTPUT_PORT, useExisting: PestDetailPresenter },
  { provide: PEST_GATEWAY, useClass: PestApiGateway }
];

export { PestDetailPresenter } from '../../adapters/pests/pest-detail.presenter';
