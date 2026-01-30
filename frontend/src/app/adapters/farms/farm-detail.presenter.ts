import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FarmDetailView } from '../../components/masters/farms/farm-detail.view';
import { LoadFarmDetailOutputPort } from '../../usecase/farms/load-farm-detail.output-port';
import { FarmDetailDataDto } from '../../usecase/farms/load-farm-detail.dtos';
import { SubscribeFarmWeatherOutputPort } from '../../usecase/farms/subscribe-farm-weather.output-port';
import { FarmWeatherUpdateDto } from '../../usecase/farms/subscribe-farm-weather.dtos';
import { DeleteFarmOutputPort } from '../../usecase/farms/delete-farm.output-port';
import { DeleteFarmSuccessDto } from '../../usecase/farms/delete-farm.dtos';

@Injectable()
export class FarmDetailPresenter
  implements LoadFarmDetailOutputPort, SubscribeFarmWeatherOutputPort, DeleteFarmOutputPort
{
  private view: FarmDetailView | null = null;

  setView(view: FarmDetailView): void {
    this.view = view;
  }

  present(dto: FarmDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      farm: dto.farm,
      fields: dto.fields
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.message
    };
  }

  presentWeather(weatherDto: FarmWeatherUpdateDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    if (!prev.farm) return;
    if (weatherDto.id !== undefined && weatherDto.id !== prev.farm.id) return;
    const status = weatherDto.weather_data_status ?? prev.farm.weather_data_status;
    this.view.control = {
      ...prev,
      farm: {
        ...prev.farm,
        weather_data_status:
          status === 'pending' || status === 'fetching' || status === 'completed' || status === 'failed'
            ? status
            : prev.farm.weather_data_status,
        weather_data_progress: weatherDto.weather_data_progress ?? prev.farm.weather_data_progress,
        weather_data_fetched_years:
          weatherDto.weather_data_fetched_years ?? prev.farm.weather_data_fetched_years,
        weather_data_total_years:
          weatherDto.weather_data_total_years ?? prev.farm.weather_data_total_years
      }
    };
  }

  onSuccess(_dto: DeleteFarmSuccessDto): void {
    // Navigation is handled by Component's onSuccess callback
  }
}
