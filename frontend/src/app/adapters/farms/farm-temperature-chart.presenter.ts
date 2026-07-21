import { Injectable } from '@angular/core';
import { FarmTemperatureChart } from '../../domain/farms/farm-temperature-chart';
import { ErrorDto } from '../../domain/shared/error.dto';
import {
  FarmTemperatureChartView,
  FarmTemperatureChartViewState
} from '../../components/masters/farms/farm-temperature-chart.view';
import { LoadFarmTemperatureChartOutputPort } from '../../usecase/farms/load-farm-temperature-chart.output-port';

const INITIAL_STATE: FarmTemperatureChartViewState = {
  loading: false,
  error: null,
  chartData: null,
  notReady: false
};

@Injectable()
export class FarmTemperatureChartPresenter implements LoadFarmTemperatureChartOutputPort {
  private view: FarmTemperatureChartView | null = null;

  setView(view: FarmTemperatureChartView): void {
    this.view = view;
  }

  present(dto: FarmTemperatureChart): void {
    if (!this.view) throw new Error('FarmTemperatureChartPresenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      chartData: dto,
      notReady: false
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('FarmTemperatureChartPresenter: view not set');
    this.view.control = {
      ...INITIAL_STATE,
      error: dto.message
    };
  }

  onNotReady(): void {
    if (!this.view) throw new Error('FarmTemperatureChartPresenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      chartData: null,
      notReady: true
    };
  }
}
