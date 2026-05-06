import { Provider } from '@angular/core';
import { PestApiGateway } from '../../adapters/pests/pest-api.gateway';
import { PestEditPresenter } from '../../adapters/pests/pest-edit.presenter';
import { LOAD_PEST_FOR_EDIT_OUTPUT_PORT } from './load-pest-for-edit.output-port';
import { LoadPestForEditUseCase } from './load-pest-for-edit.usecase';
import { PEST_GATEWAY } from './pest-gateway';
import { UPDATE_PEST_OUTPUT_PORT } from './update-pest.output-port';
import { UpdatePestUseCase } from './update-pest.usecase';

export const PEST_EDIT_PROVIDERS: readonly Provider[] = [
  PestEditPresenter,
  LoadPestForEditUseCase,
  UpdatePestUseCase,
  { provide: LOAD_PEST_FOR_EDIT_OUTPUT_PORT, useExisting: PestEditPresenter },
  { provide: UPDATE_PEST_OUTPUT_PORT, useExisting: PestEditPresenter },
  { provide: PEST_GATEWAY, useClass: PestApiGateway }
];

export { PestEditPresenter } from '../../adapters/pests/pest-edit.presenter';
