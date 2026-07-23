import { LoadFarmTemperatureChartInputDto } from './load-farm-temperature-chart.dtos';

export interface LoadFarmTemperatureChartInputPort {
  execute(dto: LoadFarmTemperatureChartInputDto): void;
}
