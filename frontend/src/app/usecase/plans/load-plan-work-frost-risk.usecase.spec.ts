import { describe, expect, it, vi } from 'vitest';
import { of, throwError } from 'rxjs';

import { LoadPlanWorkFrostRiskUseCase } from './load-plan-work-frost-risk.usecase';
import type { FieldClimateGateway } from './field-climate/field-climate.gateway';
import type { LoadPlanWorkFrostRiskOutputPort } from './load-plan-work-frost-risk.output-port';

function climateFixture(overrides: Record<string, unknown> = {}) {
  return {
    success: true,
    field_cultivation: {
      id: 1,
      field_name: 'North',
      crop_name: 'Tomato',
      start_date: '2026-03-01',
      completion_date: '2026-06-30'
    },
    farm: { id: 10, name: 'Farm', latitude: 35, longitude: 139 },
    crop_requirements: { base_temperature: 10 },
    weather_data: [{ date: '2026-08-14', temperature_min: -2 }],
    gdd_data: [{ date: '2026-08-14', gdd: 1, cumulative_gdd: 100 }],
    stages: [{ name: 'Growth', order: 1, gdd_required: 100, cumulative_gdd_required: 100, frost_threshold: 0 }],
    ...overrides
  };
}

describe('LoadPlanWorkFrostRiskUseCase', () => {
  it('counts field cultivations with frost risk for today', () => {
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: vi.fn(() => of(climateFixture()))
    };
    const output: LoadPlanWorkFrostRiskOutputPort = {
      present: vi.fn(),
      onError: vi.fn()
    };
    const useCase = new LoadPlanWorkFrostRiskUseCase(output, gateway);

    useCase.execute({
      planId: 7,
      fieldCultivationIds: [1, 2],
      today: '2026-08-14',
      loadGeneration: 3
    });

    expect(output.present).toHaveBeenCalledWith({ frostRiskCount: 2, loadGeneration: 3 });
  });

  it('returns zero when there are no field cultivations', () => {
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: vi.fn()
    };
    const output: LoadPlanWorkFrostRiskOutputPort = {
      present: vi.fn(),
      onError: vi.fn()
    };
    const useCase = new LoadPlanWorkFrostRiskUseCase(output, gateway);

    useCase.execute({ planId: 7, fieldCultivationIds: [], today: '2026-08-14' });

    expect(gateway.fetchFieldClimateData).not.toHaveBeenCalled();
    expect(output.present).toHaveBeenCalledWith({ frostRiskCount: 0, loadGeneration: undefined });
  });

  it('ignores failed climate fetches and still presents partial count', () => {
    const gateway: FieldClimateGateway = {
      fetchFieldClimateData: vi
        .fn()
        .mockReturnValueOnce(of(climateFixture()))
        .mockReturnValueOnce(throwError(() => new Error('network')))
    };
    const output: LoadPlanWorkFrostRiskOutputPort = {
      present: vi.fn(),
      onError: vi.fn()
    };
    const useCase = new LoadPlanWorkFrostRiskUseCase(output, gateway);

    useCase.execute({
      planId: 7,
      fieldCultivationIds: [1, 2],
      today: '2026-08-14'
    });

    expect(output.present).toHaveBeenCalledWith({ frostRiskCount: 1, loadGeneration: undefined });
  });
});
