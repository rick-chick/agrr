import { Provider } from '@angular/core';
import { FertilizeApiGateway } from '../../adapters/fertilizes/fertilize-api.gateway';
import { FertilizeDetailPresenter } from '../../adapters/fertilizes/fertilize-detail.presenter';
import { FERTILIZE_GATEWAY } from './fertilize-gateway';
import { LOAD_FERTILIZE_DETAIL_OUTPUT_PORT } from './load-fertilize-detail.output-port';
import { LoadFertilizeDetailUseCase } from './load-fertilize-detail.usecase';

export const FERTILIZE_DETAIL_PROVIDERS: readonly Provider[] = [
  FertilizeDetailPresenter,
  LoadFertilizeDetailUseCase,
  { provide: LOAD_FERTILIZE_DETAIL_OUTPUT_PORT, useExisting: FertilizeDetailPresenter },
  { provide: FERTILIZE_GATEWAY, useClass: FertilizeApiGateway }
];

export { FertilizeDetailPresenter } from '../../adapters/fertilizes/fertilize-detail.presenter';
