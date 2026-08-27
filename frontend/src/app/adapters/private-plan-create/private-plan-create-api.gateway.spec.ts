import { of, throwError, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PrivatePlanCreateApiGateway } from './private-plan-create-api.gateway';
import { ApiService } from '../../services/api.service';
import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';
import { CreatePrivatePlanInputDto } from '../../usecase/private-plan-create/create-private-plan.dtos';

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
    gateway = new PrivatePlanCreateApiGateway(apiClient as unknown as ApiService);
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
        planName: 'Test Plan'
      };
      vi.mocked(apiClient.post).mockReturnValue(of({ id: 123 }));

      const result = await firstValueFrom(gateway.createPlan(input));
      expect(result).toEqual({ id: 123, navigateToLearnAfterCreate: false });
      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/plans', {
        plan: {
          farm_id: 1,
          plan_name: 'Test Plan'
        }
      });
    });

    it('handles optional planName', async () => {
      const input: CreatePrivatePlanInputDto = {
        farmId: 1
      };
      vi.mocked(apiClient.post).mockReturnValue(of({ id: 456 }));

      const result = await firstValueFrom(gateway.createPlan(input));
      expect(result).toEqual({ id: 456, navigateToLearnAfterCreate: false });
      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/plans', {
        plan: {
          farm_id: 1,
          plan_name: undefined
        }
      });
    });

    it('includes carryover_from_plan_id when carryoverFromPlanId is set', async () => {
      const input: CreatePrivatePlanInputDto = {
        farmId: 1,
        planName: 'Next Plan',
        carryoverFromPlanId: 42
      };
      vi.mocked(apiClient.post).mockReturnValue(of({ id: 789 }));

      const result = await firstValueFrom(gateway.createPlan(input));
      expect(result).toEqual({ id: 789, navigateToLearnAfterCreate: false });
      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/plans', {
        plan: {
          farm_id: 1,
          plan_name: 'Next Plan',
          carryover_from_plan_id: 42
        }
      });
    });

    it('echoes navigateToLearnAfterCreate in response', async () => {
      const input: CreatePrivatePlanInputDto = {
        farmId: 1,
        navigateToLearnAfterCreate: true
      };
      vi.mocked(apiClient.post).mockReturnValue(of({ id: 321 }));

      const result = await firstValueFrom(gateway.createPlan(input));
      expect(result).toEqual({ id: 321, navigateToLearnAfterCreate: true });
    });

    it('forwards error when api fails', async () => {
      const input: CreatePrivatePlanInputDto = {
        farmId: 1
      };
      vi.mocked(apiClient.post).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.createPlan(input))).rejects.toThrow('network error');
    });
  });

  describe('fetchFarmsForPlanCreate', () => {
    it('returns empty farms with limit flag when user owns no farms but is at create limit', async () => {
      const ownedFarms: Farm[] = [
        { id: 1, name: 'Farm 1', latitude: 35, longitude: 135, region: 'jp', is_reference: false },
        { id: 2, name: 'Farm 2', latitude: 35, longitude: 135, region: 'jp', is_reference: false },
        { id: 3, name: 'Farm 3', latitude: 35, longitude: 135, region: 'jp', is_reference: false },
        { id: 4, name: 'Farm 4', latitude: 35, longitude: 135, region: 'jp', is_reference: false },
      ];
      vi.mocked(apiClient.get).mockImplementation((url: string) => {
        if (url === '/api/v1/masters/farms') {
          return of(ownedFarms);
        }
        return of({
          id: Number(url.split('/').pop()),
          name: `Farm ${url.split('/').pop()}`,
          latitude: 35,
          longitude: 135,
          region: 'jp',
          fields: [{ area: 10 }],
        });
      });

      const result = await firstValueFrom(gateway.fetchFarmsForPlanCreate());

      expect(result.farmCreateLimitReached).toBe(true);
      expect(result.farms).toHaveLength(4);
      expect(result.farms[0]).toEqual({
        id: 1,
        name: 'Farm 1',
        fieldCount: 1,
        totalArea: 10,
        hasValidFields: true,
      });
    });

    it('returns empty list with limit reached when masters farms list is empty at limit', async () => {
      vi.mocked(apiClient.get).mockReturnValue(of([]));

      const result = await firstValueFrom(gateway.fetchFarmsForPlanCreate());

      expect(result).toEqual({ farms: [], farmCreateLimitReached: false });
      expect(apiClient.get).toHaveBeenCalledTimes(1);
    });

    it('does not count reference farms toward the create limit', async () => {
      const farms: Farm[] = [
        { id: 1, name: 'Owned 1', latitude: 35, longitude: 135, region: 'jp', is_reference: false },
        { id: 2, name: 'Owned 2', latitude: 35, longitude: 135, region: 'jp', is_reference: false },
        { id: 3, name: 'Owned 3', latitude: 35, longitude: 135, region: 'jp', is_reference: false },
        { id: 4, name: 'Ref', latitude: 35, longitude: 135, region: 'jp', is_reference: true },
      ];
      vi.mocked(apiClient.get).mockImplementation((url: string) => {
        if (url === '/api/v1/masters/farms') {
          return of(farms);
        }
        return of({
          id: Number(url.split('/').pop()),
          name: `Farm ${url.split('/').pop()}`,
          latitude: 35,
          longitude: 135,
          region: 'jp',
          fields: [{ area: 5 }],
        });
      });

      const result = await firstValueFrom(gateway.fetchFarmsForPlanCreate());

      expect(result.farmCreateLimitReached).toBe(false);
      expect(result.farms).toHaveLength(4);
    });

    it('marks farms without positive field area as lacking valid fields', async () => {
      const farms: Farm[] = [
        { id: 7, name: 'Empty fields', latitude: 35, longitude: 135, region: 'jp' },
      ];
      vi.mocked(apiClient.get).mockImplementation((url: string) => {
        if (url === '/api/v1/masters/farms') {
          return of(farms);
        }
        return of({
          id: 7,
          name: 'Empty fields',
          latitude: 35,
          longitude: 135,
          region: 'jp',
          fields: [{ area: 0 }, { area: null }],
        });
      });

      const result = await firstValueFrom(gateway.fetchFarmsForPlanCreate());

      expect(result.farmCreateLimitReached).toBe(false);
      expect(result.farms[0]).toEqual({
        id: 7,
        name: 'Empty fields',
        fieldCount: 0,
        totalArea: 0,
        hasValidFields: false,
      });
    });

    it('forwards error when farm list fetch fails', async () => {
      vi.mocked(apiClient.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.fetchFarmsForPlanCreate())).rejects.toThrow('network error');
    });
  });
});