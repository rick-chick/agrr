import { InjectionToken } from '@angular/core';
import { Channel } from 'actioncable';
import { CableChannelCallbacks } from '../../domain/cable/cable-channel-callbacks';
import { FarmWeatherUpdateDto } from './subscribe-farm-weather.dtos';

export interface FarmWeatherGateway {
  subscribe(
    farmId: number,
    callbacks: CableChannelCallbacks<FarmWeatherUpdateDto>
  ): Channel;
}

export const FARM_WEATHER_GATEWAY = new InjectionToken<FarmWeatherGateway>(
  'FARM_WEATHER_GATEWAY'
);
