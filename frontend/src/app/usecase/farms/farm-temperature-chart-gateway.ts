import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import {
  FarmTemperatureChart,
  FarmTemperatureChartPeriod
} from '../../domain/farms/farm-temperature-chart';

export interface FarmTemperatureChartGateway {
  getChart(farmId: number, period: FarmTemperatureChartPeriod): Observable<FarmTemperatureChart>;
}

export const FARM_TEMPERATURE_CHART_GATEWAY = new InjectionToken<FarmTemperatureChartGateway>(
  'FARM_TEMPERATURE_CHART_GATEWAY'
);
