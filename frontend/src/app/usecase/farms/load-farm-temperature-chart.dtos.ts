import { FarmTemperatureChartPeriod } from '../../domain/farms/farm-temperature-chart';

export interface LoadFarmTemperatureChartInputDto {
  farmId: number;
  period: FarmTemperatureChartPeriod;
}
