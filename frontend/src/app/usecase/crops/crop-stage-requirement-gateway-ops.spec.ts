import { firstValueFrom, of } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { CropStageGateway } from './crop-stage-gateway';
import {
  upsertNutrientRequirement,
  upsertSunshineRequirement,
  upsertTemperatureRequirement,
  upsertThermalRequirement
} from './crop-stage-requirement-gateway-ops';

function createGateway(overrides: Partial<CropStageGateway> = {}): CropStageGateway {
  return {
    createCropStage: () => of({} as never),
    updateCropStage: () => of({} as never),
    reorderCropStages: () => of([]),
    deleteCropStage: () => of(undefined),
    getTemperatureRequirement: () => of(null),
    createTemperatureRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 1, base_temperature: 10 })),
    updateTemperatureRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 1, base_temperature: 12 })),
    deleteTemperatureRequirement: () => of(undefined),
    getThermalRequirement: () => of(null),
    createThermalRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 1, required_gdd: 100 })),
    updateThermalRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 1, required_gdd: 150 })),
    deleteThermalRequirement: () => of(undefined),
    getSunshineRequirement: () => of(null),
    createSunshineRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 1 })),
    updateSunshineRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 1 })),
    deleteSunshineRequirement: () => of(undefined),
    getNutrientRequirement: () => of(null),
    createNutrientRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 1 })),
    updateNutrientRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 1 })),
    deleteNutrientRequirement: () => of(undefined),
    ...overrides
  };
}

describe('crop-stage-requirement-gateway-ops', () => {
  it('upsertTemperatureRequirement creates when absent', async () => {
    const gateway = createGateway();
    const payload = { base_temperature: 10 };

    const result = await firstValueFrom(upsertTemperatureRequirement(gateway, 1, 2, payload));

    expect(gateway.createTemperatureRequirement).toHaveBeenCalledWith(1, 2, payload);
    expect(gateway.updateTemperatureRequirement).not.toHaveBeenCalled();
    expect(result.base_temperature).toBe(10);
  });

  it('upsertTemperatureRequirement updates when present', async () => {
    const gateway = createGateway({
      getTemperatureRequirement: () => of({ id: 1, crop_stage_id: 2, base_temperature: 8 })
    });
    const payload = { base_temperature: 12 };

    const result = await firstValueFrom(upsertTemperatureRequirement(gateway, 1, 2, payload));

    expect(gateway.updateTemperatureRequirement).toHaveBeenCalledWith(1, 2, payload);
    expect(gateway.createTemperatureRequirement).not.toHaveBeenCalled();
    expect(result.base_temperature).toBe(12);
  });

  it('upsertThermalRequirement creates when absent', async () => {
    const gateway = createGateway();
    const payload = { required_gdd: 100 };

    await firstValueFrom(upsertThermalRequirement(gateway, 1, 2, payload));

    expect(gateway.createThermalRequirement).toHaveBeenCalledWith(1, 2, payload);
    expect(gateway.updateThermalRequirement).not.toHaveBeenCalled();
  });

  it('upsertThermalRequirement updates when present', async () => {
    const gateway = createGateway({
      getThermalRequirement: () => of({ id: 1, crop_stage_id: 2, required_gdd: 80 })
    });
    const payload = { required_gdd: 150 };

    await firstValueFrom(upsertThermalRequirement(gateway, 1, 2, payload));

    expect(gateway.updateThermalRequirement).toHaveBeenCalledWith(1, 2, payload);
    expect(gateway.createThermalRequirement).not.toHaveBeenCalled();
  });

  it('upsertSunshineRequirement creates when absent', async () => {
    const gateway = createGateway();
    const payload = { minimum_sunshine_hours: 4 };

    await firstValueFrom(upsertSunshineRequirement(gateway, 1, 2, payload));

    expect(gateway.createSunshineRequirement).toHaveBeenCalledWith(1, 2, payload);
    expect(gateway.updateSunshineRequirement).not.toHaveBeenCalled();
  });

  it('upsertNutrientRequirement updates when present', async () => {
    const gateway = createGateway({
      getNutrientRequirement: () => of({ id: 1, crop_stage_id: 2, daily_uptake_n: 0.1 })
    });
    const payload = { daily_uptake_n: 0.5 };

    await firstValueFrom(upsertNutrientRequirement(gateway, 1, 2, payload));

    expect(gateway.updateNutrientRequirement).toHaveBeenCalledWith(1, 2, payload);
    expect(gateway.createNutrientRequirement).not.toHaveBeenCalled();
  });
});
