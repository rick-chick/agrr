import { Provider } from '@angular/core';
import { FertilizeApiGateway } from '../../adapters/fertilizes/fertilize-api.gateway';
import { FertilizeCreatePresenter } from '../../adapters/fertilizes/fertilize-create.presenter';
import { CREATE_FERTILIZE_OUTPUT_PORT } from './create-fertilize.output-port';
import { CreateFertilizeUseCase } from './create-fertilize.usecase';
import { FERTILIZE_GATEWAY } from './fertilize-gateway';

export const FERTILIZE_CREATE_PROVIDERS: readonly Provider[] = [
  FertilizeCreatePresenter,
  CreateFertilizeUseCase,
  { provide: CREATE_FERTILIZE_OUTPUT_PORT, useExisting: FertilizeCreatePresenter },
  { provide: FERTILIZE_GATEWAY, useClass: FertilizeApiGateway }
];

export { FertilizeCreatePresenter } from '../../adapters/fertilizes/fertilize-create.presenter';
