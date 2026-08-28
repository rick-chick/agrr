import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { Farm } from '../../domain/farms/farm';

export interface RetryFarmWeatherFetchSuccessDto {
  farm: Farm;
}

export interface RetryFarmWeatherFetchOutputPort {
  onSuccess(dto: RetryFarmWeatherFetchSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const RETRY_FARM_WEATHER_FETCH_OUTPUT_PORT = new InjectionToken<RetryFarmWeatherFetchOutputPort>(
  'RETRY_FARM_WEATHER_FETCH_OUTPUT_PORT'
);
