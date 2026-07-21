export type FarmTemperatureChartPeriod = '30d' | '90d' | '180d' | '365d';

export interface FarmTemperatureChartPoint {
  date: string;
  temperature_min?: number | null;
  temperature_mean?: number | null;
  temperature_max?: number | null;
}

export interface FarmTemperatureChartDataQuality {
  expected_days: number;
  present_days: number;
  missing_days: number;
}

export interface FarmTemperatureChart {
  farm_id: number;
  period: FarmTemperatureChartPeriod;
  start_date: string;
  end_date: string;
  observed_only: boolean;
  data_quality: FarmTemperatureChartDataQuality;
  points: FarmTemperatureChartPoint[];
}
