import { describe, expect, it, vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { FieldClimateGateway } from '../field-climate/field-climate.gateway';
import { PreviewWorkRecordClimateOutputPort } from './preview-work-record-climate.output-port';
import { PreviewWorkRecordClimateUseCase } from './preview-work-record-climate.usecase';

describe('PreviewWorkRecordClimateUseCase', () => {
  it('presents empty preview when field cultivation is missing', () => {
    const presentClimatePreview = vi.fn();
    const outputPort: PreviewWorkRecordClimateOutputPort = { presentClimatePreview };
    const gateway: FieldClimateGateway = { fetchFieldClimateData: vi.fn() };
    const useCase = new PreviewWorkRecordClimateUseCase(outputPort, gateway);

    useCase.execute({ fieldCultivationId: null, actualDate: '2026-06-12' });

    expect(presentClimatePreview).toHaveBeenCalledWith({
      gddAtActual: null,
      weatherDate: null,
      temperatureMax: null,
      temperatureMin: null,
      temperatureMean: null,
      plannedGdd: null,
      gddDelta: null,
      loading: false
    });
    expect(gateway.fetchFieldClimateData).not.toHaveBeenCalled();
  });

  it('loads climate data and presents snapshot for actual date', () => {
    const presentClimatePreview = vi.fn();
    const outputPort: PreviewWorkRecordClimateOutputPort = { presentClimatePreview };
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: vi.fn(() =>
        of({
          success: true,
          field_cultivation: { id: 1, field_name: 'A', crop_name: 'Tomato', start_date: '', completion_date: '' },
          farm: { id: 1, name: 'Farm', latitude: 0, longitude: 0 },
          crop_requirements: { base_temperature: 10 },
          weather_data: [
            {
              date: '2026-06-12',
              temperature_max: 30,
              temperature_min: 20,
              temperature_mean: 25
            }
          ],
          gdd_data: [{ date: '2026-06-12', gdd: 12, cumulative_gdd: 145.25 }],
          stages: []
        })
      )
    };
    const useCase = new PreviewWorkRecordClimateUseCase(outputPort, gateway);

    useCase.execute({ fieldCultivationId: 42, actualDate: '2026-06-12' });

    expect(gateway.fetchFieldClimateData).toHaveBeenCalledWith({
      fieldCultivationId: 42,
      planType: 'private',
      displayStartDate: '2026-06-12',
      displayEndDate: '2026-06-12'
    });
    expect(presentClimatePreview).toHaveBeenNthCalledWith(1, {
      gddAtActual: null,
      weatherDate: null,
      temperatureMax: null,
      temperatureMin: null,
      temperatureMean: null,
      plannedGdd: null,
      gddDelta: null,
      loading: true
    });
    expect(presentClimatePreview).toHaveBeenNthCalledWith(2, {
      gddAtActual: 145.25,
      weatherDate: '2026-06-12',
      temperatureMax: 30,
      temperatureMin: 20,
      temperatureMean: 25,
      plannedGdd: null,
      gddDelta: null,
      loading: false
    });
  });

  it('presents planned GDD comparison when gdd trigger is provided', () => {
    const presentClimatePreview = vi.fn();
    const outputPort: PreviewWorkRecordClimateOutputPort = { presentClimatePreview };
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: vi.fn(() =>
        of({
          success: true,
          field_cultivation: { id: 1, field_name: 'A', crop_name: 'Tomato', start_date: '', completion_date: '' },
          farm: { id: 1, name: 'Farm', latitude: 0, longitude: 0 },
          crop_requirements: { base_temperature: 10 },
          weather_data: [
            {
              date: '2026-06-12',
              temperature_max: 30,
              temperature_min: 20,
              temperature_mean: 25
            }
          ],
          gdd_data: [{ date: '2026-06-12', gdd: 12, cumulative_gdd: 145.25 }],
          stages: []
        })
      )
    };
    const useCase = new PreviewWorkRecordClimateUseCase(outputPort, gateway);

    useCase.execute({ fieldCultivationId: 42, actualDate: '2026-06-12', gddTrigger: 100 });

    expect(presentClimatePreview).toHaveBeenLastCalledWith({
      gddAtActual: 145.25,
      weatherDate: '2026-06-12',
      temperatureMax: 30,
      temperatureMin: 20,
      temperatureMean: 25,
      plannedGdd: 100,
      gddDelta: 45.3,
      loading: false
    });
  });

  it('omits planned GDD comparison when trigger is missing', () => {
    const presentClimatePreview = vi.fn();
    const outputPort: PreviewWorkRecordClimateOutputPort = { presentClimatePreview };
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: vi.fn(() =>
        of({
          success: true,
          field_cultivation: { id: 1, field_name: 'A', crop_name: 'Tomato', start_date: '', completion_date: '' },
          farm: { id: 1, name: 'Farm', latitude: 0, longitude: 0 },
          crop_requirements: { base_temperature: 10 },
          weather_data: [],
          gdd_data: [{ date: '2026-06-12', gdd: 12, cumulative_gdd: 80 }],
          stages: []
        })
      )
    };
    const useCase = new PreviewWorkRecordClimateUseCase(outputPort, gateway);

    useCase.execute({ fieldCultivationId: 42, actualDate: '2026-06-12', gddTrigger: null });

    expect(presentClimatePreview).toHaveBeenLastCalledWith(
      expect.objectContaining({
        gddAtActual: 80,
        plannedGdd: null,
        gddDelta: null,
        loading: false
      })
    );
  });

  it('presents empty preview on gateway error', () => {
    const presentClimatePreview = vi.fn();
    const outputPort: PreviewWorkRecordClimateOutputPort = { presentClimatePreview };
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: vi.fn(() => throwError(() => new Error('network')))
    };
    const useCase = new PreviewWorkRecordClimateUseCase(outputPort, gateway);

    useCase.execute({ fieldCultivationId: 42, actualDate: '2026-06-12' });

    expect(presentClimatePreview).toHaveBeenLastCalledWith({
      gddAtActual: null,
      weatherDate: null,
      temperatureMax: null,
      temperatureMin: null,
      temperatureMean: null,
      plannedGdd: null,
      gddDelta: null,
      loading: false
    });
  });
});
