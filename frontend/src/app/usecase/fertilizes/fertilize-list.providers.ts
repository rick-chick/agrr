import { Provider } from '@angular/core';
import { FertilizeApiGateway } from '../../adapters/fertilizes/fertilize-api.gateway';
import { FertilizeListPresenter } from '../../adapters/fertilizes/fertilize-list.presenter';
import { DeleteFertilizeUseCase } from './delete-fertilize.usecase';
import { DELETE_FERTILIZE_OUTPUT_PORT } from './delete-fertilize.output-port';
import { FERTILIZE_GATEWAY } from './fertilize-gateway';
import { LOAD_FERTILIZE_LIST_OUTPUT_PORT } from './load-fertilize-list.output-port';
import { LoadFertilizeListUseCase } from './load-fertilize-list.usecase';

export const FERTILIZE_LIST_PROVIDERS: readonly Provider[] = [
  FertilizeListPresenter,
  LoadFertilizeListUseCase,
  DeleteFertilizeUseCase,
  { provide: LOAD_FERTILIZE_LIST_OUTPUT_PORT, useExisting: FertilizeListPresenter },
  { provide: DELETE_FERTILIZE_OUTPUT_PORT, useExisting: FertilizeListPresenter },
  { provide: FERTILIZE_GATEWAY, useClass: FertilizeApiGateway }
];

export { FertilizeListPresenter } from '../../adapters/fertilizes/fertilize-list.presenter';
