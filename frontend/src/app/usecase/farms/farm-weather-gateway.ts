import { InjectionToken } from '@angular/core';
import { Channel } from 'actioncable';
import { FarmWeatherUpdateDto } from './subscribe-farm-weather.dtos';

export interface FarmWeatherGateway {
  subscribe(
    farmId: number,
    callbacks: { received: (message: FarmWeatherUpdateDto) => void }
  ): Channel;
}

export const FARM_WEATHER_GATEWAY = new InjectionToken<FarmWeatherGateway>(
  'FARM_WEATHER_GATEWAY'
);
