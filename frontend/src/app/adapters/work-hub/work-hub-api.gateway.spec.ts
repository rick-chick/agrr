import { describe, expect, it, vi } from 'vitest';
import { of } from 'rxjs';
import { firstValueFrom } from 'rxjs';
import { WorkHubApiGateway } from './work-hub-api.gateway';
import { ApiService } from '../../services/api.service';

describe('WorkHubApiGateway', () => {
  it('maps work hub API rows to domain rows', async () => {
    const apiClient = {
      get: vi.fn(() =>
        of([
          {
            farm_id: 1,
            farm_name: 'Farm A',
            field_count: 2,
            total_area: 80,
            has_valid_fields: true,
            plan_id: 9
          }
        ])
      )
    } as unknown as ApiService;

    const gateway = new WorkHubApiGateway(apiClient);
    const rows = await firstValueFrom(gateway.listHubFarms());

    expect(apiClient.get).toHaveBeenCalledWith('/api/v1/work/hub');
    expect(rows).toEqual([
      {
        farmId: 1,
        farmName: 'Farm A',
        fieldCount: 2,
        totalArea: 80,
        hasValidFields: true,
        planId: 9
      }
    ]);
  });
});
