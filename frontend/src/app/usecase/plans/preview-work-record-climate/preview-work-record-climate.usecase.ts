import { Inject, Injectable } from '@angular/core';
import { snapshotClimateForDate } from '../../../domain/work-schedule/work-record-climate-snapshot';
import { FIELD_CLIMATE_GATEWAY, FieldClimateGateway } from '../field-climate/field-climate.gateway';
import { PreviewWorkRecordClimateInputDto } from './preview-work-record-climate.dtos';
import { PreviewWorkRecordClimateInputPort } from './preview-work-record-climate.input-port';
import {
  PREVIEW_WORK_RECORD_CLIMATE_OUTPUT_PORT,
  PreviewWorkRecordClimateOutputPort
} from './preview-work-record-climate.output-port';

@Injectable()
export class PreviewWorkRecordClimateUseCase implements PreviewWorkRecordClimateInputPort {
  constructor(
    @Inject(PREVIEW_WORK_RECORD_CLIMATE_OUTPUT_PORT)
    private readonly outputPort: PreviewWorkRecordClimateOutputPort,
    @Inject(FIELD_CLIMATE_GATEWAY)
    private readonly fieldClimateGateway: FieldClimateGateway
  ) {}

  execute(dto: PreviewWorkRecordClimateInputDto): void {
    if (dto.fieldCultivationId == null || !dto.actualDate.trim()) {
      this.outputPort.presentClimatePreview({
        gddAtActual: null,
        weatherDate: null,
        temperatureMax: null,
        temperatureMin: null,
        temperatureMean: null,
        loading: false
      });
      return;
    }

    this.outputPort.presentClimatePreview({
      gddAtActual: null,
      weatherDate: null,
      temperatureMax: null,
      temperatureMin: null,
      temperatureMean: null,
      loading: true
    });

    this.fieldClimateGateway
      .fetchFieldClimateData({
        fieldCultivationId: dto.fieldCultivationId,
        planType: 'private',
        displayStartDate: dto.actualDate,
        displayEndDate: dto.actualDate
      })
      .subscribe({
        next: (data) => {
          const snapshot = snapshotClimateForDate(data.gdd_data, data.weather_data, dto.actualDate);
          const weather = snapshot.weatherSnapshot;
          this.outputPort.presentClimatePreview({
            gddAtActual: snapshot.gddAtActual,
            weatherDate: weather?.date ?? null,
            temperatureMax: weather?.temperature_max ?? null,
            temperatureMin: weather?.temperature_min ?? null,
            temperatureMean: weather?.temperature_mean ?? null,
            loading: false
          });
        },
        error: () => {
          this.outputPort.presentClimatePreview({
            gddAtActual: null,
            weatherDate: null,
            temperatureMax: null,
            temperatureMin: null,
            temperatureMean: null,
            loading: false
          });
        }
      });
  }
}
