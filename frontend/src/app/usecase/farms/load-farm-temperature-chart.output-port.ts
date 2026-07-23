import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FarmTemperatureChartData } from '../../domain/farms/farm-temperature-chart';

export interface LoadFarmTemperatureChartOutputPort {
  present(data: FarmTemperatureChartData): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_FARM_TEMPERATURE_CHART_OUTPUT_PORT =
  new InjectionToken<LoadFarmTemperatureChartOutputPort>('LOAD_FARM_TEMPERATURE_CHART_OUTPUT_PORT');
