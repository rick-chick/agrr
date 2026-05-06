import { Provider } from '@angular/core';
import { PestApiGateway } from '../../adapters/pests/pest-api.gateway';
import { PestCreatePresenter } from '../../adapters/pests/pest-create.presenter';
import { CREATE_PEST_OUTPUT_PORT } from './create-pest.output-port';
import { CreatePestUseCase } from './create-pest.usecase';
import { PEST_GATEWAY } from './pest-gateway';

export const PEST_CREATE_PROVIDERS: readonly Provider[] = [
  PestCreatePresenter,
  CreatePestUseCase,
  { provide: CREATE_PEST_OUTPUT_PORT, useExisting: PestCreatePresenter },
  { provide: PEST_GATEWAY, useClass: PestApiGateway }
];

export { PestCreatePresenter } from '../../adapters/pests/pest-create.presenter';
