import { of, throwError, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { CropStageApiGateway } from './crop-stage-api.gateway';
import { MastersClientService } from '../../services/masters/masters-client.service';
import {
  CropStage,
  TemperatureRequirement,
  ThermalRequirement,
  SunshineRequirement,
  NutrientRequirement
} from '../../domain/crops/crop';

describe('CropStageApiGateway', () => {
  let client: {
    get: ReturnType<typeof vi.fn>;
    post: ReturnType<typeof vi.fn>;
    patch: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
  };
  let gateway: CropStageApiGateway;

  beforeEach(() => {
    client = {
      get: vi.fn(),
      post: vi.fn(),
      patch: vi.fn(),
      delete: vi.fn()
    };
    gateway = new CropStageApiGateway(client as unknown as MastersClientService);
  });

  describe('createCropStage', () => {
    it('returns Observable<CropStage>', async () => {
      const payload = { name: 'New Stage', order: 1 };
      const cropStage: CropStage = {
        id: 1,
        crop_id: 1,
        name: 'New Stage',
        order: 1
      };
      vi.mocked(client.post).mockReturnValue(of(cropStage));

      const result = await firstValueFrom(gateway.createCropStage(1, payload));
      expect(result).toEqual(cropStage);
      expect(client.post).toHaveBeenCalledWith('/crops/1/crop_stages', { crop_stage: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { name: 'New Stage', order: 1 };
      vi.mocked(client.post).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.createCropStage(1, payload))).rejects.toThrow('network error');
    });
  });

  describe('updateCropStage', () => {
    it('returns Observable<CropStage>', async () => {
      const payload = { name: 'Updated Stage', order: 2 };
      const cropStage: CropStage = {
        id: 1,
        crop_id: 1,
        name: 'Updated Stage',
        order: 2
      };
      vi.mocked(client.patch).mockReturnValue(of(cropStage));

      const result = await firstValueFrom(gateway.updateCropStage(1, 1, payload));
      expect(result).toEqual(cropStage);
      expect(client.patch).toHaveBeenCalledWith('/crops/1/crop_stages/1', { crop_stage: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { name: 'Updated Stage' };
      vi.mocked(client.patch).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.updateCropStage(1, 1, payload))).rejects.toThrow('network error');
    });
  });

  describe('deleteCropStage', () => {
    it('returns Observable<void>', async () => {
      vi.mocked(client.delete).mockReturnValue(of(void 0));

      const result = await firstValueFrom(gateway.deleteCropStage(1, 1));
      expect(result).toBeUndefined();
      expect(client.delete).toHaveBeenCalledWith('/crops/1/crop_stages/1');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(client.delete).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.deleteCropStage(1, 1))).rejects.toThrow('network error');
    });
  });

  describe('getTemperatureRequirement', () => {
    it('returns Observable<TemperatureRequirement> when requirement exists', async () => {
      const requirement: TemperatureRequirement = {
        id: 1,
        crop_stage_id: 1,
        base_temperature: 10,
        optimal_min: 15,
        optimal_max: 25
      };
      vi.mocked(client.get).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.getTemperatureRequirement(1, 1));
      expect(result).toEqual(requirement);
      expect(client.get).toHaveBeenCalledWith('/crops/1/crop_stages/1/temperature_requirement');
    });

    it('returns null when requirement does not exist (404)', async () => {
      const error = { status: 404 };
      vi.mocked(client.get).mockReturnValue(throwError(() => error));

      const result = await firstValueFrom(gateway.getTemperatureRequirement(1, 1));
      expect(result).toBeNull();
    });

    it('forwards error when api fails with non-404 error', async () => {
      vi.mocked(client.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.getTemperatureRequirement(1, 1))).rejects.toThrow('network error');
    });
  });

  describe('createTemperatureRequirement', () => {
    it('returns Observable<TemperatureRequirement>', async () => {
      const payload = { base_temperature: 10, optimal_min: 15, optimal_max: 25 };
      const requirement: TemperatureRequirement = {
        id: 1,
        crop_stage_id: 1,
        ...payload
      };
      vi.mocked(client.post).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.createTemperatureRequirement(1, 1, payload));
      expect(result).toEqual(requirement);
      expect(client.post).toHaveBeenCalledWith('/crops/1/crop_stages/1/temperature_requirement', { temperature_requirement: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { base_temperature: 10 };
      vi.mocked(client.post).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.createTemperatureRequirement(1, 1, payload))).rejects.toThrow('network error');
    });
  });

  describe('updateTemperatureRequirement', () => {
    it('returns Observable<TemperatureRequirement>', async () => {
      const payload = { base_temperature: 12, optimal_min: 18, optimal_max: 28 };
      const requirement: TemperatureRequirement = {
        id: 1,
        crop_stage_id: 1,
        ...payload
      };
      vi.mocked(client.patch).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.updateTemperatureRequirement(1, 1, payload));
      expect(result).toEqual(requirement);
      expect(client.patch).toHaveBeenCalledWith('/crops/1/crop_stages/1/temperature_requirement', { temperature_requirement: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { base_temperature: 12 };
      vi.mocked(client.patch).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.updateTemperatureRequirement(1, 1, payload))).rejects.toThrow('network error');
    });
  });

  describe('deleteTemperatureRequirement', () => {
    it('returns Observable<void>', async () => {
      vi.mocked(client.delete).mockReturnValue(of(void 0));

      const result = await firstValueFrom(gateway.deleteTemperatureRequirement(1, 1));
      expect(result).toBeUndefined();
      expect(client.delete).toHaveBeenCalledWith('/crops/1/crop_stages/1/temperature_requirement');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(client.delete).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.deleteTemperatureRequirement(1, 1))).rejects.toThrow('network error');
    });
  });

  describe('getThermalRequirement', () => {
    it('returns Observable<ThermalRequirement> when requirement exists', async () => {
      const requirement: ThermalRequirement = {
        id: 1,
        crop_stage_id: 1,
        required_gdd: 100
      };
      vi.mocked(client.get).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.getThermalRequirement(1, 1));
      expect(result).toEqual(requirement);
      expect(client.get).toHaveBeenCalledWith('/crops/1/crop_stages/1/thermal_requirement');
    });

    it('returns null when requirement does not exist (404)', async () => {
      const error = { status: 404 };
      vi.mocked(client.get).mockReturnValue(throwError(() => error));

      const result = await firstValueFrom(gateway.getThermalRequirement(1, 1));
      expect(result).toBeNull();
    });

    it('forwards error when api fails with non-404 error', async () => {
      vi.mocked(client.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.getThermalRequirement(1, 1))).rejects.toThrow('network error');
    });
  });

  describe('createThermalRequirement', () => {
    it('returns Observable<ThermalRequirement>', async () => {
      const payload = { required_gdd: 150 };
      const requirement: ThermalRequirement = {
        id: 1,
        crop_stage_id: 1,
        ...payload
      };
      vi.mocked(client.post).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.createThermalRequirement(1, 1, payload));
      expect(result).toEqual(requirement);
      expect(client.post).toHaveBeenCalledWith('/crops/1/crop_stages/1/thermal_requirement', { thermal_requirement: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { required_gdd: 150 };
      vi.mocked(client.post).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.createThermalRequirement(1, 1, payload))).rejects.toThrow('network error');
    });
  });

  describe('updateThermalRequirement', () => {
    it('returns Observable<ThermalRequirement>', async () => {
      const payload = { required_gdd: 200 };
      const requirement: ThermalRequirement = {
        id: 1,
        crop_stage_id: 1,
        ...payload
      };
      vi.mocked(client.patch).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.updateThermalRequirement(1, 1, payload));
      expect(result).toEqual(requirement);
      expect(client.patch).toHaveBeenCalledWith('/crops/1/crop_stages/1/thermal_requirement', { thermal_requirement: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { required_gdd: 200 };
      vi.mocked(client.patch).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.updateThermalRequirement(1, 1, payload))).rejects.toThrow('network error');
    });
  });

  describe('deleteThermalRequirement', () => {
    it('returns Observable<void>', async () => {
      vi.mocked(client.delete).mockReturnValue(of(void 0));

      const result = await firstValueFrom(gateway.deleteThermalRequirement(1, 1));
      expect(result).toBeUndefined();
      expect(client.delete).toHaveBeenCalledWith('/crops/1/crop_stages/1/thermal_requirement');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(client.delete).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.deleteThermalRequirement(1, 1))).rejects.toThrow('network error');
    });
  });

  describe('getSunshineRequirement', () => {
    it('returns Observable<SunshineRequirement> when requirement exists', async () => {
      const requirement: SunshineRequirement = {
        id: 1,
        crop_stage_id: 1,
        minimum_sunshine_hours: 4,
        target_sunshine_hours: 8
      };
      vi.mocked(client.get).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.getSunshineRequirement(1, 1));
      expect(result).toEqual(requirement);
      expect(client.get).toHaveBeenCalledWith('/crops/1/crop_stages/1/sunshine_requirement');
    });

    it('returns null when requirement does not exist (404)', async () => {
      const error = { status: 404 };
      vi.mocked(client.get).mockReturnValue(throwError(() => error));

      const result = await firstValueFrom(gateway.getSunshineRequirement(1, 1));
      expect(result).toBeNull();
    });

    it('forwards error when api fails with non-404 error', async () => {
      vi.mocked(client.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.getSunshineRequirement(1, 1))).rejects.toThrow('network error');
    });
  });

  describe('createSunshineRequirement', () => {
    it('returns Observable<SunshineRequirement>', async () => {
      const payload = { minimum_sunshine_hours: 5, target_sunshine_hours: 9 };
      const requirement: SunshineRequirement = {
        id: 1,
        crop_stage_id: 1,
        ...payload
      };
      vi.mocked(client.post).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.createSunshineRequirement(1, 1, payload));
      expect(result).toEqual(requirement);
      expect(client.post).toHaveBeenCalledWith('/crops/1/crop_stages/1/sunshine_requirement', { sunshine_requirement: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { minimum_sunshine_hours: 5 };
      vi.mocked(client.post).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.createSunshineRequirement(1, 1, payload))).rejects.toThrow('network error');
    });
  });

  describe('updateSunshineRequirement', () => {
    it('returns Observable<SunshineRequirement>', async () => {
      const payload = { minimum_sunshine_hours: 6, target_sunshine_hours: 10 };
      const requirement: SunshineRequirement = {
        id: 1,
        crop_stage_id: 1,
        ...payload
      };
      vi.mocked(client.patch).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.updateSunshineRequirement(1, 1, payload));
      expect(result).toEqual(requirement);
      expect(client.patch).toHaveBeenCalledWith('/crops/1/crop_stages/1/sunshine_requirement', { sunshine_requirement: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { target_sunshine_hours: 10 };
      vi.mocked(client.patch).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.updateSunshineRequirement(1, 1, payload))).rejects.toThrow('network error');
    });
  });

  describe('deleteSunshineRequirement', () => {
    it('returns Observable<void>', async () => {
      vi.mocked(client.delete).mockReturnValue(of(void 0));

      const result = await firstValueFrom(gateway.deleteSunshineRequirement(1, 1));
      expect(result).toBeUndefined();
      expect(client.delete).toHaveBeenCalledWith('/crops/1/crop_stages/1/sunshine_requirement');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(client.delete).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.deleteSunshineRequirement(1, 1))).rejects.toThrow('network error');
    });
  });

  describe('getNutrientRequirement', () => {
    it('returns Observable<NutrientRequirement> when requirement exists', async () => {
      const requirement: NutrientRequirement = {
        id: 1,
        crop_stage_id: 1,
        daily_uptake_n: 1.5,
        daily_uptake_p: 0.3,
        daily_uptake_k: 2.0,
        region: 'jp'
      };
      vi.mocked(client.get).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.getNutrientRequirement(1, 1));
      expect(result).toEqual(requirement);
      expect(client.get).toHaveBeenCalledWith('/crops/1/crop_stages/1/nutrient_requirement');
    });

    it('returns null when requirement does not exist (404)', async () => {
      const error = { status: 404 };
      vi.mocked(client.get).mockReturnValue(throwError(() => error));

      const result = await firstValueFrom(gateway.getNutrientRequirement(1, 1));
      expect(result).toBeNull();
    });

    it('forwards error when api fails with non-404 error', async () => {
      vi.mocked(client.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.getNutrientRequirement(1, 1))).rejects.toThrow('network error');
    });
  });

  describe('createNutrientRequirement', () => {
    it('returns Observable<NutrientRequirement>', async () => {
      const payload = { daily_uptake_n: 2.0, daily_uptake_p: 0.4, daily_uptake_k: 2.5, region: 'us' };
      const requirement: NutrientRequirement = {
        id: 1,
        crop_stage_id: 1,
        ...payload
      };
      vi.mocked(client.post).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.createNutrientRequirement(1, 1, payload));
      expect(result).toEqual(requirement);
      expect(client.post).toHaveBeenCalledWith('/crops/1/crop_stages/1/nutrient_requirement', { nutrient_requirement: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { daily_uptake_n: 2.0 };
      vi.mocked(client.post).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.createNutrientRequirement(1, 1, payload))).rejects.toThrow('network error');
    });
  });

  describe('updateNutrientRequirement', () => {
    it('returns Observable<NutrientRequirement>', async () => {
      const payload = { daily_uptake_n: 2.5, daily_uptake_p: 0.5, daily_uptake_k: 3.0 };
      const requirement: NutrientRequirement = {
        id: 1,
        crop_stage_id: 1,
        ...payload,
        region: 'us'
      };
      vi.mocked(client.patch).mockReturnValue(of(requirement));

      const result = await firstValueFrom(gateway.updateNutrientRequirement(1, 1, payload));
      expect(result).toEqual(requirement);
      expect(client.patch).toHaveBeenCalledWith('/crops/1/crop_stages/1/nutrient_requirement', { nutrient_requirement: payload });
    });

    it('forwards error when api fails', async () => {
      const payload = { daily_uptake_n: 2.5 };
      vi.mocked(client.patch).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.updateNutrientRequirement(1, 1, payload))).rejects.toThrow('network error');
    });
  });

  describe('deleteNutrientRequirement', () => {
    it('returns Observable<void>', async () => {
      vi.mocked(client.delete).mockReturnValue(of(void 0));

      const result = await firstValueFrom(gateway.deleteNutrientRequirement(1, 1));
      expect(result).toBeUndefined();
      expect(client.delete).toHaveBeenCalledWith('/crops/1/crop_stages/1/nutrient_requirement');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(client.delete).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.deleteNutrientRequirement(1, 1))).rejects.toThrow('network error');
    });
  });
});