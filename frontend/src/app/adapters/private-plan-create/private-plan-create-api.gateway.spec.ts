import { of, throwError, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PrivatePlanCreateApiGateway } from './private-plan-create-api.gateway';
import { ApiClientService } from '../../services/api-client.service';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';
import { CreatePrivatePlanInputDto, CreatePrivatePlanResponseDto } from '../../usecase/private-plan-create/create-private-plan.dtos';

describe('PrivatePlanCreateApiGateway', () => {
  let apiClient: {
    get: ReturnType<typeof vi.fn>;
    post: ReturnType<typeof vi.fn>;
  };
  let gateway: PrivatePlanCreateApiGateway;

  beforeEach(() => {
    apiClient = {
      get: vi.fn(),
      post: vi.fn()
    };
    gateway = new PrivatePlanCreateApiGateway(apiClient as unknown as ApiClientService);
  });

  describe('fetchFarms', () => {
    it('returns Observable<Farm[]>', async () => {
      const farms: Farm[] = [
        { id: 1, name: 'Farm 1', latitude: 35.0, longitude: 135.0, region: 'Region 1' },
        { id: 2, name: 'Farm 2', latitude: 36.0, longitude: 136.0, region: 'Region 2' }
      ];
      vi.mocked(apiClient.get).mockReturnValue(of(farms));

      const result = await firstValueFrom(gateway.fetchFarms());
      expect(result).toEqual(farms);
      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/masters/farms');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(apiClient.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.fetchFarms())).rejects.toThrow('network error');
    });
  });

  describe('fetchFarm', () => {
    it('returns Observable<FarmWithTotalAreaDto> with calculated totalArea', async () => {
      const farmWithFields = {
        id: 1,
        name: 'Farm 1',
        latitude: 35.0,
        longitude: 135.0,
        region: 'Region 1',
        fields: [
          { area: 100 },
          { area: 200 },
          { area: null }
        ]
      };
      vi.mocked(apiClient.get).mockReturnValue(of(farmWithFields));

      const result = await firstValueFrom(gateway.fetchFarm(1));
      expect(result.farm).toEqual({
        id: 1,
        name: 'Farm 1',
        latitude: 35.0,
        longitude: 135.0,
        region: 'Region 1'
      });
      expect(result.totalArea).toBe(300);
      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/masters/farms/1');
    });

    it('returns totalArea 0 when fields is empty', async () => {
      const farmWithEmptyFields = {
        id: 1,
        name: 'Farm 1',
        latitude: 35.0,
        longitude: 135.0,
        region: 'Region 1',
        fields: []
      };
      vi.mocked(apiClient.get).mockReturnValue(of(farmWithEmptyFields));

      const result = await firstValueFrom(gateway.fetchFarm(1));
      expect(result.farm).toEqual({
        id: 1,
        name: 'Farm 1',
        latitude: 35.0,
        longitude: 135.0,
        region: 'Region 1'
      });
      expect(result.totalArea).toBe(0);
    });

    it('returns totalArea 0 when fields is undefined', async () => {
      const farmWithoutFields = {
        id: 1,
        name: 'Farm 1',
        latitude: 35.0,
        longitude: 135.0,
        region: 'Region 1'
      };
      vi.mocked(apiClient.get).mockReturnValue(of(farmWithoutFields));

      const result = await firstValueFrom(gateway.fetchFarm(1));
      expect(result.farm).toEqual({
        id: 1,
        name: 'Farm 1',
        latitude: 35.0,
        longitude: 135.0,
        region: 'Region 1'
      });
      expect(result.totalArea).toBe(0);
    });

    it('forwards error when api fails', async () => {
      vi.mocked(apiClient.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.fetchFarm(1))).rejects.toThrow('network error');
    });
  });

  describe('fetchCrops', () => {
    it('returns Observable<Crop[]>', async () => {
      const crops: Crop[] = [
        { id: 1, name: 'Crop 1', variety: null, is_reference: false, groups: ['group1'] },
        { id: 2, name: 'Crop 2', variety: 'Variety 2', is_reference: false, groups: ['group2'] }
      ];
      vi.mocked(apiClient.get).mockReturnValue(of(crops));

      const result = await firstValueFrom(gateway.fetchCrops());
      expect(result).toEqual(crops);
      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/masters/crops');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(apiClient.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.fetchCrops())).rejects.toThrow('network error');
    });
  });

  describe('createPlan', () => {
    it('returns Observable<CreatePrivatePlanResponseDto>', async () => {
      const input: CreatePrivatePlanInputDto = {
        farmId: 1,
        planName: 'Test Plan',
        cropIds: [1, 2, 3]
      };
      const response: CreatePrivatePlanResponseDto = { id: 123 };
      vi.mocked(apiClient.post).mockReturnValue(of(response));

      const result = await firstValueFrom(gateway.createPlan(input));
      expect(result).toEqual(response);
      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/plans', {
        plan: {
          farm_id: 1,
          plan_name: 'Test Plan',
          crop_ids: [1, 2, 3]
        }
      });
    });

    it('handles optional planName', async () => {
      const input: CreatePrivatePlanInputDto = {
        farmId: 1,
        cropIds: [1, 2]
      };
      const response: CreatePrivatePlanResponseDto = { id: 456 };
      vi.mocked(apiClient.post).mockReturnValue(of(response));

      const result = await firstValueFrom(gateway.createPlan(input));
      expect(result).toEqual(response);
      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/plans', {
        plan: {
          farm_id: 1,
          plan_name: undefined,
          crop_ids: [1, 2]
        }
      });
    });

    it('forwards error when api fails', async () => {
      const input: CreatePrivatePlanInputDto = {
        farmId: 1,
        cropIds: [1, 2]
      };
      vi.mocked(apiClient.post).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.createPlan(input))).rejects.toThrow('network error');
    });
  });
});