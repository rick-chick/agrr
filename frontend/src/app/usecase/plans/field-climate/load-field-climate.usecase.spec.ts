import { of, throwError } from 'rxjs';
import { describe, it, expect } from 'vitest';
import { FieldCultivationClimateData } from '../../../domain/plans/field-cultivation-climate-data';
import { FieldClimateGateway } from './field-climate.gateway';
import { LoadFieldClimateOutputPort } from './load-field-climate.output-port';
import { LoadFieldClimateUseCase } from './load-field-climate.usecase';

describe('LoadFieldClimateUseCase', () => {
  const sampleData: FieldCultivationClimateData = {
    success: true,
    field_cultivation: {
      id: 1,
      field_name: 'North Field',
      crop_name: 'Tomato',
      start_date: '2026-02-01',
      completion_date: '2026-05-30'
    },
    farm: {
      id: 2,
      name: 'Kawasaki Farm',
      latitude: 35.5,
      longitude: 139.7
    },
    crop_requirements: {
      base_temperature: 12,
      optimal_temperature_range: {
        min: 18,
        max: 28,
        low_stress: 15,
        high_stress: 33
      }
    },
    weather_data: [
      { date: '2026-02-01', temperature_max: 20.5, temperature_min: 9.3, temperature_mean: 14.9 }
    ],
    gdd_data: [
      {
        date: '2026-02-01',
        gdd: 2.9,
        cumulative_gdd: 2.9,
        temperature: 14.9,
        current_stage: '播種〜発芽'
      }
    ],
    stages: [
      {
        name: '播種〜発芽',
        order: 1,
        gdd_required: 75,
        cumulative_gdd_required: 75,
        optimal_temperature_min: 18,
        optimal_temperature_max: 28,
        low_stress_threshold: 15,
        high_stress_threshold: 33
      }
    ],
    progress_result: {},
    debug_info: {}
  };

  it('passes gateway result to outputPort.present', () => {
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: () => of(sampleData)
    };

    let presented: FieldCultivationClimateData | null = null;
    const outputPort: LoadFieldClimateOutputPort = {
      present: (dto) => {
        presented = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadFieldClimateUseCase(outputPort, gateway);
    useCase.execute({ fieldCultivationId: 1, planType: 'private' });

    expect(presented).toEqual(sampleData);
  });

  it('forwards gateway errors to outputPort.onError', () => {
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: () => throwError(() => new Error('connection lost'))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: LoadFieldClimateOutputPort = {
      present: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new LoadFieldClimateUseCase(outputPort, gateway);
    useCase.execute({ fieldCultivationId: 1, planType: 'public' });

    expect(receivedError).not.toBeNull();
    expect(receivedError?.message).toContain('connection lost');
  });
});
