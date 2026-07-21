import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import {
  FarmTemperatureChart,
  FarmTemperatureChartPeriod
} from '../../domain/farms/farm-temperature-chart';
import { MastersClientService } from '../../services/masters/masters-client.service';
import {
  FarmTemperatureChartGateway
} from '../../usecase/farms/farm-temperature-chart-gateway';

@Injectable()
export class FarmTemperatureChartApiGateway implements FarmTemperatureChartGateway {
  constructor(private readonly client: MastersClientService) {}

  getChart(farmId: number, period: FarmTemperatureChartPeriod): Observable<FarmTemperatureChart> {
    return this.client.get<FarmTemperatureChart>(`/farms/${farmId}/temperature_chart`, { period });
  }
}
