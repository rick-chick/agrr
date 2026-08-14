import { describe, expect, it, vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { FieldClimateGateway } from '../field-climate/field-climate.gateway';
import { PreviewWorkRowMiniClimateOutputPort } from './preview-work-row-mini-climate.output-port';
import { PreviewWorkRowMiniClimateUseCase } from './preview-work-row-mini-climate.usecase';

describe('PreviewWorkRowMiniClimateUseCase', () => {
  it('presents empty preview when field cultivation is missing', () => {
    const presentMiniClimate = vi.fn();
    const outputPort: PreviewWorkRowMiniClimateOutputPort = { presentMiniClimate };
    const gateway: FieldClimateGateway = { fetchFieldClimateData: vi.fn() };
    const useCase = new PreviewWorkRowMiniClimateUseCase(outputPort, gateway);

    useCase.execute({ fieldCultivationId: null, today: '2026-06-17' });

    expect(presentMiniClimate).toHaveBeenCalledWith({
      cumulativeGdd: null,
      dailyWeather: [],
      startDate: '2026-06-11',
      endDate: '2026-06-17',
      loading: false
    });
    expect(gateway.fetchFieldClimateData).not.toHaveBeenCalled();
  });

  it('loads 7-day climate data and presents summary', () => {
    const presentMiniClimate = vi.fn();
    const outputPort: PreviewWorkRowMiniClimateOutputPort = { presentMiniClimate };
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: vi.fn(() =>
        of({
          success: true,
          field_cultivation: { id: 1, field_name: 'A', crop_name: 'Tomato', start_date: '', completion_date: '' },
          farm: { id: 1, name: 'Farm', latitude: 0, longitude: 0 },
          crop_requirements: { base_temperature: 10 },
          weather_data: [
            {
              date: '2026-06-15',
              temperature_max: 28,
              temperature_min: 18,
              temperature_mean: 23
            },
            {
              date: '2026-06-16',
              temperature_max: 30,
              temperature_min: 20,
              temperature_mean: 25
            }
          ],
          gdd_data: [{ date: '2026-06-17', gdd: 8, cumulative_gdd: 145.5 }],
          stages: []
        })
      )
    };
    const useCase = new PreviewWorkRowMiniClimateUseCase(outputPort, gateway);

    useCase.execute({ fieldCultivationId: 42, today: '2026-06-17' });

    expect(gateway.fetchFieldClimateData).toHaveBeenCalledWith({
      fieldCultivationId: 42,
      planType: 'private',
      displayStartDate: '2026-06-11',
      displayEndDate: '2026-06-17'
    });
    expect(presentMiniClimate).toHaveBeenNthCalledWith(1, {
      cumulativeGdd: null,
      dailyWeather: [],
      startDate: '2026-06-11',
      endDate: '2026-06-17',
      loading: true
    });
    expect(presentMiniClimate).toHaveBeenNthCalledWith(2, {
      cumulativeGdd: 145.5,
      dailyWeather: [
        {
          date: '2026-06-15',
          temperatureMax: 28,
          temperatureMin: 18,
          temperatureMean: 23
        },
        {
          date: '2026-06-16',
          temperatureMax: 30,
          temperatureMin: 20,
          temperatureMean: 25
        }
      ],
      startDate: '2026-06-11',
      endDate: '2026-06-17',
      loading: false
    });
  });

  it('presents empty preview on gateway error', () => {
    const presentMiniClimate = vi.fn();
    const outputPort: PreviewWorkRowMiniClimateOutputPort = { presentMiniClimate };
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: vi.fn(() => throwError(() => new Error('network')))
    };
    const useCase = new PreviewWorkRowMiniClimateUseCase(outputPort, gateway);

    useCase.execute({ fieldCultivationId: 42, today: '2026-06-17' });

    expect(presentMiniClimate).toHaveBeenLastCalledWith({
      cumulativeGdd: null,
      dailyWeather: [],
      startDate: '2026-06-11',
      endDate: '2026-06-17',
      loading: false
    });
  });
});
