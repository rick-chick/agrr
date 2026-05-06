import { Provider } from '@angular/core';
import { CreateFieldPresenter } from '../../adapters/farms/create-field.presenter';
import { DeleteFieldPresenter } from '../../adapters/farms/delete-field.presenter';
import { FarmApiGateway } from '../../adapters/farms/farm-api.gateway';
import { FarmDetailPresenter } from '../../adapters/farms/farm-detail.presenter';
import { FarmWeatherChannelGateway } from '../../adapters/farms/farm-weather-channel.gateway';
import { UpdateFieldPresenter } from '../../adapters/farms/update-field.presenter';
import { CreateFieldUseCase } from './create-field.usecase';
import { CREATE_FIELD_OUTPUT_PORT } from './create-field.output-port';
import { DeleteFarmUseCase } from './delete-farm.usecase';
import { DELETE_FARM_OUTPUT_PORT } from './delete-farm.output-port';
import { DeleteFieldUseCase } from './delete-field.usecase';
import { DELETE_FIELD_OUTPUT_PORT } from './delete-field.output-port';
import { FARM_GATEWAY } from './farm-gateway';
import { FARM_WEATHER_GATEWAY } from './farm-weather-gateway';
import { LOAD_FARM_DETAIL_OUTPUT_PORT } from './load-farm-detail.output-port';
import { LoadFarmDetailUseCase } from './load-farm-detail.usecase';
import { SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT } from './subscribe-farm-weather.output-port';
import { SubscribeFarmWeatherUseCase } from './subscribe-farm-weather.usecase';
import { UPDATE_FIELD_OUTPUT_PORT } from './update-field.output-port';
import { UpdateFieldUseCase } from './update-field.usecase';

export const FARM_DETAIL_PROVIDERS: readonly Provider[] = [
  FarmDetailPresenter,
  LoadFarmDetailUseCase,
  SubscribeFarmWeatherUseCase,
  DeleteFarmUseCase,
  CreateFieldPresenter,
  CreateFieldUseCase,
  UpdateFieldPresenter,
  UpdateFieldUseCase,
  DeleteFieldPresenter,
  DeleteFieldUseCase,
  { provide: LOAD_FARM_DETAIL_OUTPUT_PORT, useExisting: FarmDetailPresenter },
  { provide: SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT, useExisting: FarmDetailPresenter },
  { provide: DELETE_FARM_OUTPUT_PORT, useExisting: FarmDetailPresenter },
  { provide: CREATE_FIELD_OUTPUT_PORT, useExisting: CreateFieldPresenter },
  { provide: UPDATE_FIELD_OUTPUT_PORT, useExisting: UpdateFieldPresenter },
  { provide: DELETE_FIELD_OUTPUT_PORT, useExisting: DeleteFieldPresenter },
  { provide: FARM_GATEWAY, useClass: FarmApiGateway },
  { provide: FARM_WEATHER_GATEWAY, useClass: FarmWeatherChannelGateway }
];

export { FarmDetailPresenter } from '../../adapters/farms/farm-detail.presenter';
export { CreateFieldPresenter } from '../../adapters/farms/create-field.presenter';
export { UpdateFieldPresenter } from '../../adapters/farms/update-field.presenter';
export { DeleteFieldPresenter } from '../../adapters/farms/delete-field.presenter';
