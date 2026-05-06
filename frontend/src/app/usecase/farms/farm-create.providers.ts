import { Provider } from '@angular/core';
import { FarmApiGateway } from '../../adapters/farms/farm-api.gateway';
import { FarmCreatePresenter } from '../../adapters/farms/farm-create.presenter';
import { CREATE_FARM_OUTPUT_PORT } from './create-farm.output-port';
import { CreateFarmUseCase } from './create-farm.usecase';
import { FARM_GATEWAY } from './farm-gateway';

export const FARM_CREATE_PROVIDERS: readonly Provider[] = [
  FarmCreatePresenter,
  CreateFarmUseCase,
  { provide: CREATE_FARM_OUTPUT_PORT, useExisting: FarmCreatePresenter },
  { provide: FARM_GATEWAY, useClass: FarmApiGateway }
];

export { FarmCreatePresenter } from '../../adapters/farms/farm-create.presenter';
