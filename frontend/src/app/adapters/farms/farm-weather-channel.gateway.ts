import { Injectable } from '@angular/core';
import { Channel } from 'actioncable';
import { OptimizationService } from '../../services/plans/optimization.service';
import { FarmWeatherGateway } from '../../usecase/farms/farm-weather-gateway';
import { FarmWeatherUpdateDto } from '../../usecase/farms/subscribe-farm-weather.dtos';

@Injectable()
export class FarmWeatherChannelGateway implements FarmWeatherGateway {
  constructor(private readonly optimizationService: OptimizationService) {}

  subscribe(
    farmId: number,
    callbacks: { received: (message: FarmWeatherUpdateDto) => void }
  ): Channel {
    return this.optimizationService.subscribe(
      'FarmChannel',
      { farm_id: farmId },
      { received: callbacks.received }
    );
  }
}
