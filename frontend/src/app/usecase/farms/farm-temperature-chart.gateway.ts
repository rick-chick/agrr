import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { FarmTemperatureChartData, FarmTemperatureChartPeriod } from '../../domain/farms/farm-temperature-chart';

export interface FarmTemperatureChartGateway {
  load(farmId: number, period: FarmTemperatureChartPeriod): Observable<FarmTemperatureChartData>;
}

export const FARM_TEMPERATURE_CHART_GATEWAY = new InjectionToken<FarmTemperatureChartGateway>(
  'FARM_TEMPERATURE_CHART_GATEWAY'
);
