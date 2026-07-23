import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import {
  FarmTemperatureChartData,
  FarmTemperatureChartPeriod
} from '../../domain/farms/farm-temperature-chart';
import { FarmTemperatureChartGateway } from '../../usecase/farms/farm-temperature-chart.gateway';

@Injectable()
export class FarmTemperatureChartApiGateway implements FarmTemperatureChartGateway {
  constructor(private readonly client: MastersClientService) {}

  load(farmId: number, period: FarmTemperatureChartPeriod): Observable<FarmTemperatureChartData> {
    return this.client.get<FarmTemperatureChartData>(
      `/farms/${farmId}/temperature_chart?period=${period}`
    );
  }
}
