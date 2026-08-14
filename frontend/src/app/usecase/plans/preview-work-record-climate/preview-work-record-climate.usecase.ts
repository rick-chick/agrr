import { Inject, Injectable } from '@angular/core';
import { gddDeltaFromValues, parseGddTrigger } from '../../../domain/plans/work-record-variance';
import { snapshotClimateForDate } from '../../../domain/work-schedule/work-record-climate-snapshot';
import { FIELD_CLIMATE_GATEWAY, FieldClimateGateway } from '../field-climate/field-climate.gateway';
import { PreviewWorkRecordClimateInputDto, PreviewWorkRecordClimateStateDto } from './preview-work-record-climate.dtos';
import { PreviewWorkRecordClimateInputPort } from './preview-work-record-climate.input-port';
import {
  PREVIEW_WORK_RECORD_CLIMATE_OUTPUT_PORT,
  PreviewWorkRecordClimateOutputPort
} from './preview-work-record-climate.output-port';

function emptyClimatePreviewState(loading = false): PreviewWorkRecordClimateStateDto {
  return {
    gddAtActual: null,
    weatherDate: null,
    temperatureMax: null,
    temperatureMin: null,
    temperatureMean: null,
    plannedGdd: null,
    gddDelta: null,
    loading
  };
}

function climatePreviewFromSnapshot(
  snapshot: ReturnType<typeof snapshotClimateForDate>,
  gddTrigger: string | number | null | undefined,
  loading: boolean
): PreviewWorkRecordClimateStateDto {
  const weather = snapshot.weatherSnapshot;
  const plannedGdd = parseGddTrigger(gddTrigger);
  const gddAtActual = snapshot.gddAtActual;
  return {
    gddAtActual,
    weatherDate: weather?.date ?? null,
    temperatureMax: weather?.temperature_max ?? null,
    temperatureMin: weather?.temperature_min ?? null,
    temperatureMean: weather?.temperature_mean ?? null,
    plannedGdd,
    gddDelta: gddDeltaFromValues(gddAtActual, plannedGdd),
    loading
  };
}

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
      this.outputPort.presentClimatePreview(emptyClimatePreviewState());
      return;
    }

    this.outputPort.presentClimatePreview(emptyClimatePreviewState(true));

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
          this.outputPort.presentClimatePreview(
            climatePreviewFromSnapshot(snapshot, dto.gddTrigger, false)
          );
        },
        error: () => {
          this.outputPort.presentClimatePreview(emptyClimatePreviewState());
        }
      });
  }
}
