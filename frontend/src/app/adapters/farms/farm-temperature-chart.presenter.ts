import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FarmTemperatureChartData } from '../../domain/farms/farm-temperature-chart';
import { FarmTemperatureChartView } from '../../components/masters/farms/farm-temperature-chart.view';
import { LoadFarmTemperatureChartOutputPort } from '../../usecase/farms/load-farm-temperature-chart.output-port';

@Injectable()
export class FarmTemperatureChartPresenter implements LoadFarmTemperatureChartOutputPort {
  private view: FarmTemperatureChartView | null = null;

  setView(view: FarmTemperatureChartView): void {
    this.view = view;
  }

  present(data: FarmTemperatureChartData): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      chartData: data
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.message,
      chartData: null
    };
  }
}
