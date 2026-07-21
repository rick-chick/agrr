import { InjectionToken } from '@angular/core';
import { FarmTemperatureChart } from '../../domain/farms/farm-temperature-chart';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadFarmTemperatureChartOutputPort {
  present(dto: FarmTemperatureChart): void;
  onError(dto: ErrorDto): void;
  onNotReady(): void;
}

export const LOAD_FARM_TEMPERATURE_CHART_OUTPUT_PORT =
  new InjectionToken<LoadFarmTemperatureChartOutputPort>('LOAD_FARM_TEMPERATURE_CHART_OUTPUT_PORT');
