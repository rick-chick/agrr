import { WorkRowMiniClimateDailyWeather } from '../../../domain/work-schedule/work-row-mini-climate';

export interface PreviewWorkRowMiniClimateInputDto {
  fieldCultivationId: number | null;
  today: string;
}

export interface PreviewWorkRowMiniClimateStateDto {
  cumulativeGdd: number | null;
  dailyWeather: WorkRowMiniClimateDailyWeather[];
  startDate: string;
  endDate: string;
  loading: boolean;
}
