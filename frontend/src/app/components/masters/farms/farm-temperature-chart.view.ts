import { FarmTemperatureChart } from '../../../domain/farms/farm-temperature-chart';

export type FarmTemperatureChartViewState = {
  loading: boolean;
  error: string | null;
  chartData: FarmTemperatureChart | null;
  notReady: boolean;
};

export interface FarmTemperatureChartView {
  get control(): FarmTemperatureChartViewState;
  set control(value: FarmTemperatureChartViewState);
}
