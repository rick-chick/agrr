import { SubscribeFarmWeatherInputDto } from './subscribe-farm-weather.dtos';

export interface SubscribeFarmWeatherInputPort {
  execute(dto: SubscribeFarmWeatherInputDto): void;
}
