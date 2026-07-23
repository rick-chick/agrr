import { Provider } from '@angular/core';
import { FarmTemperatureChartApiGateway } from '../../adapters/farms/farm-temperature-chart-api.gateway';
import { FarmTemperatureChartPresenter } from '../../adapters/farms/farm-temperature-chart.presenter';
import { FARM_TEMPERATURE_CHART_GATEWAY } from './farm-temperature-chart.gateway';
import { LOAD_FARM_TEMPERATURE_CHART_OUTPUT_PORT } from './load-farm-temperature-chart.output-port';
import { LoadFarmTemperatureChartUseCase } from './load-farm-temperature-chart.usecase';

export const FARM_TEMPERATURE_CHART_PROVIDERS: readonly Provider[] = [
  FarmTemperatureChartPresenter,
  LoadFarmTemperatureChartUseCase,
  FarmTemperatureChartApiGateway,
  { provide: LOAD_FARM_TEMPERATURE_CHART_OUTPUT_PORT, useExisting: FarmTemperatureChartPresenter },
  { provide: FARM_TEMPERATURE_CHART_GATEWAY, useExisting: FarmTemperatureChartApiGateway }
];

export { FarmTemperatureChartPresenter };
