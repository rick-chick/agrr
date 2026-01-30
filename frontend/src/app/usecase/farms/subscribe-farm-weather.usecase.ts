import { Inject, Injectable } from '@angular/core';
import { SubscribeFarmWeatherInputDto } from './subscribe-farm-weather.dtos';
import { SubscribeFarmWeatherInputPort } from './subscribe-farm-weather.input-port';
import {
  SubscribeFarmWeatherOutputPort,
  SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT
} from './subscribe-farm-weather.output-port';
import { FARM_WEATHER_GATEWAY, FarmWeatherGateway } from './farm-weather-gateway';

@Injectable()
export class SubscribeFarmWeatherUseCase implements SubscribeFarmWeatherInputPort {
  constructor(
    @Inject(SUBSCRIBE_FARM_WEATHER_OUTPUT_PORT) private readonly outputPort: SubscribeFarmWeatherOutputPort,
    @Inject(FARM_WEATHER_GATEWAY) private readonly weatherGateway: FarmWeatherGateway
  ) {}

  execute(dto: SubscribeFarmWeatherInputDto): void {
    const channel = this.weatherGateway.subscribe(dto.farmId, {
      received: (message) => this.outputPort.presentWeather(message)
    });
    dto.onSubscribed?.(channel);
  }
}
