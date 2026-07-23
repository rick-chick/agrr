import { FarmTemperatureChartData } from '../../../domain/farms/farm-temperature-chart';

export interface FarmTemperatureChartViewState {
  loading: boolean;
  error: string | null;
  chartData: FarmTemperatureChartData | null;
}

export interface FarmTemperatureChartView {
  control: FarmTemperatureChartViewState;
}
