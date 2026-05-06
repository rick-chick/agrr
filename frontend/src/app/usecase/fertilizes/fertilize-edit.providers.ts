import { Provider } from '@angular/core';
import { FertilizeApiGateway } from '../../adapters/fertilizes/fertilize-api.gateway';
import { FertilizeEditPresenter } from '../../adapters/fertilizes/fertilize-edit.presenter';
import { FERTILIZE_GATEWAY } from './fertilize-gateway';
import { LOAD_FERTILIZE_FOR_EDIT_OUTPUT_PORT } from './load-fertilize-for-edit.output-port';
import { LoadFertilizeForEditUseCase } from './load-fertilize-for-edit.usecase';
import { UPDATE_FERTILIZE_OUTPUT_PORT } from './update-fertilize.output-port';
import { UpdateFertilizeUseCase } from './update-fertilize.usecase';

export const FERTILIZE_EDIT_PROVIDERS: readonly Provider[] = [
  FertilizeEditPresenter,
  LoadFertilizeForEditUseCase,
  UpdateFertilizeUseCase,
  { provide: LOAD_FERTILIZE_FOR_EDIT_OUTPUT_PORT, useExisting: FertilizeEditPresenter },
  { provide: UPDATE_FERTILIZE_OUTPUT_PORT, useExisting: FertilizeEditPresenter },
  { provide: FERTILIZE_GATEWAY, useClass: FertilizeApiGateway }
];

export { FertilizeEditPresenter } from '../../adapters/fertilizes/fertilize-edit.presenter';
