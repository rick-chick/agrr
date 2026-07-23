import { of, throwError } from 'rxjs';
import { describe, expect, it } from 'vitest';
import { FarmTemperatureChartData } from '../../domain/farms/farm-temperature-chart';
import { FarmTemperatureChartGateway } from './farm-temperature-chart.gateway';
import { LoadFarmTemperatureChartOutputPort } from './load-farm-temperature-chart.output-port';
import { LoadFarmTemperatureChartUseCase } from './load-farm-temperature-chart.usecase';

describe('LoadFarmTemperatureChartUseCase', () => {
  const sampleData: FarmTemperatureChartData = {
    farm_id: 1,
    period: '90d',
    start_date: '2026-04-24',
    end_date: '2026-07-23',
    observed_only: true,
    data_quality: {
      expected_days: 90,
      present_days: 90,
      missing_days: 0
    },
    points: [
      {
        date: '2026-07-22',
        temperature_min: 18.2,
        temperature_mean: 24.5,
        temperature_max: 30.1
      }
    ]
  };

  it('passes gateway result to outputPort.present', () => {
    const gateway: FarmTemperatureChartGateway = {
      load: () => of(sampleData)
    };

    let presented: FarmTemperatureChartData | null = null;
    const outputPort: LoadFarmTemperatureChartOutputPort = {
      present: (dto) => {
        presented = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadFarmTemperatureChartUseCase(outputPort, gateway);
    useCase.execute({ farmId: 1, period: '90d' });

    expect(presented).toEqual(sampleData);
  });

  it('maps HTTP error body to outputPort.onError', () => {
    const gateway: FarmTemperatureChartGateway = {
      load: () =>
        throwError(() => ({
          status: 409,
          error: { error: 'farms.weather_section.chart_fetching' }
        }))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: LoadFarmTemperatureChartOutputPort = {
      present: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new LoadFarmTemperatureChartUseCase(outputPort, gateway);
    useCase.execute({ farmId: 1, period: '30d' });

    expect(receivedError).not.toBeNull();
    expect(receivedError?.message).toBe('farms.weather_section.chart_fetching');
  });

  it('falls back to default i18n key when error shape is unknown', () => {
    const gateway: FarmTemperatureChartGateway = {
      load: () => throwError(() => new Error('network down'))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: LoadFarmTemperatureChartOutputPort = {
      present: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new LoadFarmTemperatureChartUseCase(outputPort, gateway);
    useCase.execute({ farmId: 1, period: '30d' });

    expect(receivedError?.message).toBe('network down');
  });
});
