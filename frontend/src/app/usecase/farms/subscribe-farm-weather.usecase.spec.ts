import { describe, expect, it, vi } from 'vitest';
import { SubscribeFarmWeatherUseCase } from './subscribe-farm-weather.usecase';
import { FarmWeatherGateway } from './farm-weather-gateway';
import { SubscribeFarmWeatherOutputPort } from './subscribe-farm-weather.output-port';
import { FarmWeatherUpdateDto } from './subscribe-farm-weather.dtos';

describe('SubscribeFarmWeatherUseCase', () => {
  it('subscribes via gateway and forwards weather updates to output port', () => {
    let received: ((message: FarmWeatherUpdateDto) => void) | undefined;
    const channel = { unsubscribe: vi.fn() };
    const gateway = {
      subscribe: vi.fn(
        (_farmId: number, callbacks: { received: (message: FarmWeatherUpdateDto) => void }) => {
          received = callbacks.received;
          return channel;
        }
      )
    } as unknown as FarmWeatherGateway;
    const outputPort: SubscribeFarmWeatherOutputPort = {
      presentWeather: vi.fn()
    };
    const useCase = new SubscribeFarmWeatherUseCase(outputPort, gateway);
    const onSubscribed = vi.fn();

    useCase.execute({ farmId: 42, onSubscribed });

    expect(gateway.subscribe).toHaveBeenCalledWith(42, expect.any(Object));
    expect(onSubscribed).toHaveBeenCalledWith(channel);

    const dto: FarmWeatherUpdateDto = {
      id: 42,
      weather_data_status: 'fetching',
      weather_data_progress: 40,
      weather_data_fetched_years: 2,
      weather_data_total_years: 5
    };
    received?.(dto);
    expect(outputPort.presentWeather).toHaveBeenCalledWith(dto);
  });
});
