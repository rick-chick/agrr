import { firstValueFrom, of, throwError } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PublicPlanApiGateway } from './public-plan-api.gateway';
import { ApiClientService } from '../../services/api-client.service';
import { SavePublicPlanResponse } from '../../usecase/public-plans/public-plan-gateway';

describe('PublicPlanApiGateway', () => {
  let apiClient: { post: ReturnType<typeof vi.fn> };
  let gateway: PublicPlanApiGateway;

  beforeEach(() => {
    apiClient = { post: vi.fn() };
    gateway = new PublicPlanApiGateway(apiClient as unknown as ApiClientService);
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
});