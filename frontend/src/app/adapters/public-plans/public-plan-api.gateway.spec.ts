import { firstValueFrom, of, throwError } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PublicPlanApiGateway } from './public-plan-api.gateway';
import { ApiClientService } from '../../services/api-client.service';
import {
  SavePublicPlanResponse,
  CreatePublicPlanResponse
} from '../../usecase/public-plans/public-plan-gateway';

describe('PublicPlanApiGateway', () => {
  let apiClient: { get: ReturnType<typeof vi.fn>; post: ReturnType<typeof vi.fn> };
  let gateway: PublicPlanApiGateway;

  beforeEach(() => {
    apiClient = { get: vi.fn(), post: vi.fn() };
    gateway = new PublicPlanApiGateway(apiClient as unknown as ApiClientService);
  });

  describe('createPlan', () => {
    it('returns Observable<CreatePublicPlanResponse> with plan_id on success', async () => {
      const response: CreatePublicPlanResponse = { plan_id: 123 };
      vi.mocked(apiClient.post).mockReturnValue(of(response));

      const result = await firstValueFrom(
        gateway.createPlan(1, 'home_garden', [10, 20])
      );
      expect(result).toEqual(response);
      expect(result.plan_id).toBe(123);
      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/public_plans/plans', {
        farm_id: 1,
        farm_size_id: 'home_garden',
        crop_ids: [10, 20]
      });
    });

    it('returns different plan_id on subsequent calls', async () => {
      const response1: CreatePublicPlanResponse = { plan_id: 123 };
      const response2: CreatePublicPlanResponse = { plan_id: 124 };
      vi.mocked(apiClient.post)
        .mockReturnValueOnce(of(response1))
        .mockReturnValueOnce(of(response2));

      const result1 = await firstValueFrom(
        gateway.createPlan(1, 'home_garden', [10, 20])
      );
      const result2 = await firstValueFrom(
        gateway.createPlan(1, 'home_garden', [10, 20])
      );

      expect(result1.plan_id).toBe(123);
      expect(result2.plan_id).toBe(124);
      expect(result1.plan_id).not.toBe(result2.plan_id);
    });

    it('forwards error when api fails', async () => {
      vi.mocked(apiClient.post).mockReturnValue(
        throwError(() => new Error('network error'))
      );

      await expect(
        firstValueFrom(gateway.createPlan(1, 'home_garden', [10, 20]))
      ).rejects.toThrow(/network error/);
    });
  });

  describe('savePlan', () => {
    it('returns Observable<SavePublicPlanResponse> on success', async () => {
      const response: SavePublicPlanResponse = { success: true };
      vi.mocked(apiClient.post).mockReturnValue(of(response));

      const result = await firstValueFrom(gateway.savePlan(123));
      expect(result).toEqual(response);
      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/public_plans/save_plan', { plan_id: 123 });
    });

    it('returns Observable<SavePublicPlanResponse> with error on failure', async () => {
      const response: SavePublicPlanResponse = { success: false, error: 'Save failed' };
      vi.mocked(apiClient.post).mockReturnValue(of(response));

      const result = await firstValueFrom(gateway.savePlan(123));
      expect(result).toEqual(response);
      expect(result.success).toBe(false);
      expect(result.error).toBe('Save failed');
      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/public_plans/save_plan', { plan_id: 123 });
    });

    it('forwards error when api fails', async () => {
      vi.mocked(apiClient.post).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.savePlan(123))).rejects.toThrow(/network error/);
    });
  });

  describe('getFarms', () => {
    it('calls API with region parameter', async () => {
      const farms = [{ id: 1, name: 'Test Farm', region: 'jp', latitude: 35.0, longitude: 139.0 }];
      vi.mocked(apiClient.get).mockReturnValue(of(farms));

      const result = await firstValueFrom(gateway.getFarms('jp'));
      expect(result).toEqual(farms);
      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/public_plans/farms', { params: { region: 'jp' } });
    });

    it('calls API without region parameter', async () => {
      const farms = [{ id: 1, name: 'Test Farm', region: 'jp', latitude: 35.0, longitude: 139.0 }];
      vi.mocked(apiClient.get).mockReturnValue(of(farms));

      const result = await firstValueFrom(gateway.getFarms());
      expect(result).toEqual(farms);
      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/public_plans/farms', { params: undefined });
    });
  });

  describe('getFarmSizes', () => {
    it('calls API and returns farm sizes', async () => {
      const farmSizes = [{ id: 'home_garden', name: 'Home Garden', area_sqm: 30 }];
      vi.mocked(apiClient.get).mockReturnValue(of(farmSizes));

      const result = await firstValueFrom(gateway.getFarmSizes());
      expect(result).toEqual(farmSizes);
      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/public_plans/farm_sizes');
    });
  });
});