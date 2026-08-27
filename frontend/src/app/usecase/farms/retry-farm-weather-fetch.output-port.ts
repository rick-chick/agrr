import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { RetryFarmWeatherFetchSuccessDto } from './retry-farm-weather-fetch.dtos';

export interface RetryFarmWeatherFetchOutputPort {
  presentRetryWeatherFetch(dto: RetryFarmWeatherFetchSuccessDto): void;
  onRetryWeatherFetchError(dto: ErrorDto): void;
}

export const RETRY_FARM_WEATHER_FETCH_OUTPUT_PORT = new InjectionToken<RetryFarmWeatherFetchOutputPort>(
  'RETRY_FARM_WEATHER_FETCH_OUTPUT_PORT'
);
