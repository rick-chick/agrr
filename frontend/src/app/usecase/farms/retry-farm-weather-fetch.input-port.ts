import { RetryFarmWeatherFetchInputDto } from './retry-farm-weather-fetch.dtos';

export interface RetryFarmWeatherFetchInputPort {
  execute(dto: RetryFarmWeatherFetchInputDto): void;
}
