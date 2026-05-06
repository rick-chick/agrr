import { Provider } from '@angular/core';
import { FarmApiGateway } from '../../adapters/farms/farm-api.gateway';
import { FarmEditPresenter } from '../../adapters/farms/farm-edit.presenter';
import { FARM_GATEWAY } from './farm-gateway';
import { LOAD_FARM_FOR_EDIT_OUTPUT_PORT } from './load-farm-for-edit.output-port';
import { LoadFarmForEditUseCase } from './load-farm-for-edit.usecase';
import { UPDATE_FARM_OUTPUT_PORT } from './update-farm.output-port';
import { UpdateFarmUseCase } from './update-farm.usecase';

export const FARM_EDIT_PROVIDERS: readonly Provider[] = [
  FarmEditPresenter,
  LoadFarmForEditUseCase,
  UpdateFarmUseCase,
  { provide: LOAD_FARM_FOR_EDIT_OUTPUT_PORT, useExisting: FarmEditPresenter },
  { provide: UPDATE_FARM_OUTPUT_PORT, useExisting: FarmEditPresenter },
  { provide: FARM_GATEWAY, useClass: FarmApiGateway }
];

export { FarmEditPresenter } from '../../adapters/farms/farm-edit.presenter';
