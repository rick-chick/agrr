import { Inject, Injectable } from '@angular/core';
import { RetryFarmWeatherFetchInputDto } from './retry-farm-weather-fetch.dtos';
import { RetryFarmWeatherFetchInputPort } from './retry-farm-weather-fetch.input-port';
import {
  RETRY_FARM_WEATHER_FETCH_OUTPUT_PORT,
  RetryFarmWeatherFetchOutputPort
} from './retry-farm-weather-fetch.output-port';
import { FARM_GATEWAY, FarmGateway } from './farm-gateway';

@Injectable()
export class RetryFarmWeatherFetchUseCase implements RetryFarmWeatherFetchInputPort {
  constructor(
    @Inject(RETRY_FARM_WEATHER_FETCH_OUTPUT_PORT)
    private readonly outputPort: RetryFarmWeatherFetchOutputPort,
    @Inject(FARM_GATEWAY) private readonly farmGateway: FarmGateway
  ) {}

  execute(dto: RetryFarmWeatherFetchInputDto): void {
    this.farmGateway.fetchWeatherData(dto.farmId).subscribe({
      next: (farm) => {
        this.outputPort.onSuccess({ farm });
        dto.onSettled?.();
      },
      error: (err: Error & { error?: { error?: string; errors?: string[] } }) => {
        this.outputPort.onError({
          message:
            err.error?.error ??
            err.error?.errors?.join(', ') ??
            err?.message ??
            'Unknown error'
        });
        dto.onSettled?.();
      }
    });
  }
}
