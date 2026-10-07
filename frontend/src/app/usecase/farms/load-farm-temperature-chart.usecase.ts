import { Inject, Injectable } from '@angular/core';
import { apiErrorMessage } from '../../core/api-error-message';
import { ErrorDto } from '../../domain/shared/error.dto';
import { LoadFarmTemperatureChartInputDto } from './load-farm-temperature-chart.dtos';
import { LoadFarmTemperatureChartInputPort } from './load-farm-temperature-chart.input-port';
import {
  LoadFarmTemperatureChartOutputPort,
  LOAD_FARM_TEMPERATURE_CHART_OUTPUT_PORT
} from './load-farm-temperature-chart.output-port';
import {
  FARM_TEMPERATURE_CHART_GATEWAY,
  FarmTemperatureChartGateway
} from './farm-temperature-chart.gateway';

@Injectable()
export class LoadFarmTemperatureChartUseCase implements LoadFarmTemperatureChartInputPort {
  constructor(
    @Inject(LOAD_FARM_TEMPERATURE_CHART_OUTPUT_PORT)
    private readonly outputPort: LoadFarmTemperatureChartOutputPort,
    @Inject(FARM_TEMPERATURE_CHART_GATEWAY)
    private readonly gateway: FarmTemperatureChartGateway
  ) {}

  execute(dto: LoadFarmTemperatureChartInputDto): void {
    this.gateway.load(dto.farmId, dto.period).subscribe({
      next: (data) => this.outputPort.present(data),
      error: (err: unknown) => {
        const errorDto: ErrorDto = { message: apiErrorMessage(err) };
        this.outputPort.onError(errorDto);
      }
    });
  }
}