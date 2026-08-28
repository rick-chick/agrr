import { of, throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import type { Farm } from '../../domain/farms/farm';
import { RetryFarmWeatherFetchUseCase } from './retry-farm-weather-fetch.usecase';
import type { FarmGateway } from './farm-gateway';
import type { RetryFarmWeatherFetchOutputPort } from './retry-farm-weather-fetch.output-port';

const updatedFarm: Farm = {
  id: 42,
  name: 'North Farm',
  latitude: 35,
  longitude: 139,
  region: 'jp',
  weather_data_status: 'fetching',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-02T00:00:00Z'
};

describe('RetryFarmWeatherFetchUseCase', () => {
  function createUseCase(
    gateway: Pick<FarmGateway, 'fetchWeatherData'>,
    outputPort: RetryFarmWeatherFetchOutputPort
  ): RetryFarmWeatherFetchUseCase {
    return new RetryFarmWeatherFetchUseCase(outputPort, gateway as FarmGateway);
  }

  it('calls fetchWeatherData and forwards farm to onSuccess', () => {
    const fetchWeatherData = vi.fn(() => of(updatedFarm));
    const onSuccess = vi.fn();
    const onError = vi.fn();
    const useCase = createUseCase({ fetchWeatherData }, { onSuccess, onError });

    useCase.execute({ farmId: 42 });

    expect(fetchWeatherData).toHaveBeenCalledWith(42);
    expect(onSuccess).toHaveBeenCalledWith({ farm: updatedFarm });
    expect(onError).not.toHaveBeenCalled();
  });

  it('invokes onSettled after successful retry', () => {
    const onSettled = vi.fn();
    const useCase = createUseCase(
      { fetchWeatherData: vi.fn(() => of(updatedFarm)) },
      { onSuccess: vi.fn(), onError: vi.fn() }
    );

    useCase.execute({ farmId: 42, onSettled });

    expect(onSettled).toHaveBeenCalledOnce();
  });

  it('maps API error body to onError message', () => {
    const onError = vi.fn();
    const useCase = createUseCase(
      {
        fetchWeatherData: vi.fn(() =>
          throwError(() => ({
            message: 'Http failure',
            error: { error: 'Weather fetch already in progress' }
          }))
        )
      },
      { onSuccess: vi.fn(), onError }
    );

    useCase.execute({ farmId: 42 });

    expect(onError).toHaveBeenCalledWith({
      message: 'Weather fetch already in progress'
    });
  });

  it('joins errors array when error.error is absent', () => {
    const onError = vi.fn();
    const useCase = createUseCase(
      {
        fetchWeatherData: vi.fn(() =>
          throwError(() => ({
            message: 'Http failure',
            error: { errors: ['Farm not found', 'Permission denied'] }
          }))
        )
      },
      { onSuccess: vi.fn(), onError }
    );

    useCase.execute({ farmId: 99 });

    expect(onError).toHaveBeenCalledWith({
      message: 'Farm not found, Permission denied'
    });
  });

  it('falls back to err.message then Unknown error', () => {
    const onError = vi.fn();
    const useCase = createUseCase(
      {
        fetchWeatherData: vi.fn(() =>
          throwError(() => ({
            message: 'Network timeout'
          }))
        )
      },
      { onSuccess: vi.fn(), onError }
    );

    useCase.execute({ farmId: 1 });

    expect(onError).toHaveBeenCalledWith({ message: 'Network timeout' });
  });

  it('invokes onSettled after failed retry', () => {
    const onSettled = vi.fn();
    const useCase = createUseCase(
      {
        fetchWeatherData: vi.fn(() => throwError(() => new Error('boom')))
      },
      { onSuccess: vi.fn(), onError: vi.fn() }
    );

    useCase.execute({ farmId: 1, onSettled });

    expect(onSettled).toHaveBeenCalledOnce();
  });
});
