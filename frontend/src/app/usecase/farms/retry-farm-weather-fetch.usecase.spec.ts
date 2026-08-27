import { TestBed } from '@angular/core/testing';
import { vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { RetryFarmWeatherFetchUseCase } from './retry-farm-weather-fetch.usecase';
import { RETRY_FARM_WEATHER_FETCH_OUTPUT_PORT } from './retry-farm-weather-fetch.output-port';
import { FARM_GATEWAY, FarmGateway } from './farm-gateway';

describe('RetryFarmWeatherFetchUseCase', () => {
  let useCase: RetryFarmWeatherFetchUseCase;
  let gateway: { retryWeatherFetch: ReturnType<typeof vi.fn> };
  let outputPort: {
    presentRetryWeatherFetch: ReturnType<typeof vi.fn>;
    onRetryWeatherFetchError: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    gateway = { retryWeatherFetch: vi.fn() };
    outputPort = { presentRetryWeatherFetch: vi.fn(), onRetryWeatherFetchError: vi.fn() };

    TestBed.configureTestingModule({
      providers: [
        RetryFarmWeatherFetchUseCase,
        { provide: FARM_GATEWAY, useValue: gateway },
        { provide: RETRY_FARM_WEATHER_FETCH_OUTPUT_PORT, useValue: outputPort }
      ]
    });

    useCase = TestBed.inject(RetryFarmWeatherFetchUseCase);
  });

  it('calls gateway retryWeatherFetch and forwards success to output port', () => {
    const farm = {
      id: 5,
      name: 'Farm',
      region: 'jp',
      latitude: 35,
      longitude: 139,
      weather_data_status: 'fetching' as const,
      weather_data_progress: 0
    };
    gateway.retryWeatherFetch.mockReturnValue(of(farm));

    useCase.execute({ farmId: 5 });

    expect(gateway.retryWeatherFetch).toHaveBeenCalledWith(5);
    expect(outputPort.presentRetryWeatherFetch).toHaveBeenCalledWith({ farm });
    expect(outputPort.onRetryWeatherFetchError).not.toHaveBeenCalled();
  });

  it('forwards gateway errors to output port', () => {
    gateway.retryWeatherFetch.mockReturnValue(
      throwError(() => ({ error: { error: 'farms.flash.no_permission' } }))
    );

    useCase.execute({ farmId: 5 });

    expect(outputPort.onRetryWeatherFetchError).toHaveBeenCalledWith({
      message: 'farms.flash.no_permission'
    });
  });
});
