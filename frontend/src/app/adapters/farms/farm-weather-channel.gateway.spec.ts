import { describe, expect, it, vi } from 'vitest';
import { FarmWeatherChannelGateway } from './farm-weather-channel.gateway';
import { OptimizationService } from '../../services/plans/optimization.service';
import { FarmWeatherUpdateDto } from '../../usecase/farms/subscribe-farm-weather.dtos';

describe('FarmWeatherChannelGateway', () => {
  it('subscribes to FarmChannel and forwards weather progress messages', () => {
    let received: ((message: FarmWeatherUpdateDto) => void) | undefined;
    let disconnected: (() => void) | undefined;
    let rejected: (() => void) | undefined;
    const optimizationService = {
      subscribe: vi.fn(
        (
          channel: string,
          params: Record<string, unknown>,
          callbacks: {
            received: (message: FarmWeatherUpdateDto) => void;
            disconnected?: () => void;
            rejected?: () => void;
          }
        ) => {
          received = callbacks.received;
          disconnected = callbacks.disconnected;
          rejected = callbacks.rejected;
          return { unsubscribe: vi.fn() };
        }
      )
    };
    const gateway = new FarmWeatherChannelGateway(
      optimizationService as unknown as OptimizationService
    );
    const onReceived = vi.fn();

    gateway.subscribe(42, { received: onReceived });

    expect(optimizationService.subscribe).toHaveBeenCalledWith(
      'FarmChannel',
      { farm_id: 42 },
      expect.objectContaining({ received: expect.any(Function) })
    );

    const payload: FarmWeatherUpdateDto = {
      id: 42,
      weather_data_status: 'fetching',
      weather_data_progress: 60,
      weather_data_fetched_years: 3,
      weather_data_total_years: 5
    };
    received?.(payload);
    expect(onReceived).toHaveBeenCalledWith(payload);
  });

  it('forwards disconnected and rejected callbacks to OptimizationService', () => {
    let disconnected: (() => void) | undefined;
    let rejected: (() => void) | undefined;
    const optimizationService = {
      subscribe: vi.fn(
        (
          _channel: string,
          _params: Record<string, unknown>,
          callbacks: { received: () => void; disconnected?: () => void; rejected?: () => void }
        ) => {
          disconnected = callbacks.disconnected;
          rejected = callbacks.rejected;
          return { unsubscribe: vi.fn() };
        }
      )
    };
    const gateway = new FarmWeatherChannelGateway(
      optimizationService as unknown as OptimizationService
    );
    const onDisconnected = vi.fn();
    const onRejected = vi.fn();

    gateway.subscribe(42, {
      received: vi.fn(),
      disconnected: onDisconnected,
      rejected: onRejected
    });

    disconnected?.();
    rejected?.();
    expect(onDisconnected).toHaveBeenCalledTimes(1);
    expect(onRejected).toHaveBeenCalledTimes(1);
  });
});
