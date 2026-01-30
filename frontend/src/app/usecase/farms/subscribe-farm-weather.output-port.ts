import { InjectionToken } from '@angular/core';
import { FarmWeatherUpdateDto } from './subscribe-farm-weather.dtos';

export interface SubscribeFarmWeatherOutputPort {
  presentWeather(dto: FarmWeatherUpdateDto): void;
}

export const SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT = new InjectionToken<SubscribeFarmWeatherOutputPort>(
  'SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT'
);
