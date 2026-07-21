import { HttpErrorResponse } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import {
  FARM_TEMPERATURE_CHART_GATEWAY,
  FarmTemperatureChartGateway
} from './farm-temperature-chart-gateway';
import { LoadFarmTemperatureChartInputDto } from './load-farm-temperature-chart.dtos';
import { LoadFarmTemperatureChartInputPort } from './load-farm-temperature-chart.input-port';
import {
  LOAD_FARM_TEMPERATURE_CHART_OUTPUT_PORT,
  LoadFarmTemperatureChartOutputPort
} from './load-farm-temperature-chart.output-port';

@Injectable()
export class LoadFarmTemperatureChartUseCase implements LoadFarmTemperatureChartInputPort {
  constructor(
    @Inject(LOAD_FARM_TEMPERATURE_CHART_OUTPUT_PORT)
    private readonly outputPort: LoadFarmTemperatureChartOutputPort,
    @Inject(FARM_TEMPERATURE_CHART_GATEWAY)
    private readonly gateway: FarmTemperatureChartGateway
  ) {}

  execute(dto: LoadFarmTemperatureChartInputDto): void {
    this.gateway.getChart(dto.farmId, dto.period).subscribe({
      next: (data) => this.outputPort.present(data),
      error: (err: unknown) => {
        if (err instanceof HttpErrorResponse && err.status === 409) {
          this.outputPort.onNotReady();
          return;
        }

        const errorDto: ErrorDto = {
          message:
            err instanceof HttpErrorResponse
              ? (err.error?.error ?? err.message ?? 'farms.weather_section.chart_load_failed')
              : err instanceof Error
                ? err.message
                : 'farms.weather_section.chart_load_failed'
        };
        this.outputPort.onError(errorDto);
      }
    });
  }
}
