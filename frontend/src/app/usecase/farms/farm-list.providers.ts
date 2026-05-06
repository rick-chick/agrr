import { Provider } from '@angular/core';
import { FarmApiGateway } from '../../adapters/farms/farm-api.gateway';
import { FarmListPresenter } from '../../adapters/farms/farm-list.presenter';
import { DeleteFarmUseCase } from './delete-farm.usecase';
import { DELETE_FARM_OUTPUT_PORT } from './delete-farm.output-port';
import { FARM_GATEWAY } from './farm-gateway';
import { LOAD_FARM_LIST_OUTPUT_PORT } from './load-farm-list.output-port';
import { LoadFarmListUseCase } from './load-farm-list.usecase';

export const FARM_LIST_PROVIDERS: readonly Provider[] = [
  FarmListPresenter,
  LoadFarmListUseCase,
  DeleteFarmUseCase,
  { provide: LOAD_FARM_LIST_OUTPUT_PORT, useExisting: FarmListPresenter },
  { provide: DELETE_FARM_OUTPUT_PORT, useExisting: FarmListPresenter },
  { provide: FARM_GATEWAY, useClass: FarmApiGateway }
];

export { FarmListPresenter } from '../../adapters/farms/farm-list.presenter';
