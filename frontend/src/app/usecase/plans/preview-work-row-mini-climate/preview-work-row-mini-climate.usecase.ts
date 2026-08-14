import { Inject, Injectable } from '@angular/core';
import {
  buildWorkRowMiniClimateSummary,
  computeWorkRowMiniClimateDateRange
} from '../../../domain/work-schedule/work-row-mini-climate';
import { FIELD_CLIMATE_GATEWAY, FieldClimateGateway } from '../field-climate/field-climate.gateway';
import {
  PreviewWorkRowMiniClimateInputDto,
  PreviewWorkRowMiniClimateStateDto
} from './preview-work-row-mini-climate.dtos';
import { PreviewWorkRowMiniClimateInputPort } from './preview-work-row-mini-climate.input-port';
import {
  PREVIEW_WORK_ROW_MINI_CLIMATE_OUTPUT_PORT,
  PreviewWorkRowMiniClimateOutputPort
} from './preview-work-row-mini-climate.output-port';

function emptyMiniClimateState(
  today: string,
  loading = false
): PreviewWorkRowMiniClimateStateDto {
  const { startDate, endDate } = computeWorkRowMiniClimateDateRange(today);
  return {
    cumulativeGdd: null,
    dailyWeather: [],
    startDate,
    endDate,
    loading
  };
}

@Injectable()
export class PreviewWorkRowMiniClimateUseCase implements PreviewWorkRowMiniClimateInputPort {
  constructor(
    @Inject(PREVIEW_WORK_ROW_MINI_CLIMATE_OUTPUT_PORT)
    private readonly outputPort: PreviewWorkRowMiniClimateOutputPort,
    @Inject(FIELD_CLIMATE_GATEWAY)
    private readonly fieldClimateGateway: FieldClimateGateway
  ) {}

  execute(dto: PreviewWorkRowMiniClimateInputDto): void {
    if (dto.fieldCultivationId == null || !dto.today.trim()) {
      this.outputPort.presentMiniClimate(emptyMiniClimateState(dto.today));
      return;
    }

    const { startDate, endDate } = computeWorkRowMiniClimateDateRange(dto.today);
    this.outputPort.presentMiniClimate(emptyMiniClimateState(dto.today, true));

    this.fieldClimateGateway
      .fetchFieldClimateData({
        fieldCultivationId: dto.fieldCultivationId,
        planType: 'private',
        displayStartDate: startDate,
        displayEndDate: endDate
      })
      .subscribe({
        next: (data) => {
          const summary = buildWorkRowMiniClimateSummary(
            data.gdd_data,
            data.weather_data,
            startDate,
            endDate
          );
          this.outputPort.presentMiniClimate({
            cumulativeGdd: summary.cumulativeGdd,
            dailyWeather: summary.dailyWeather,
            startDate,
            endDate,
            loading: false
          });
        },
        error: () => {
          this.outputPort.presentMiniClimate(emptyMiniClimateState(dto.today));
        }
      });
  }
}
