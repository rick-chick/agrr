import { describe, expect, it, vi } from 'vitest';
import { of } from 'rxjs';
import { firstValueFrom } from 'rxjs';

import { WorkVarianceApiGateway } from './work-variance-api.gateway';

describe('WorkVarianceApiGateway', () => {
  it('maps variance portfolio API rows to domain rows', async () => {
    const apiClient = {
      get: vi.fn().mockReturnValue(
        of([
          {
            farm_id: 1,
            farm_name: 'Farm A',
            plan_id: 10,
            plan_year: 2026,
            status: 'completed',
            unrecorded_count: 2,
            gdd_delay_count: 1,
            threshold_exceeded_count: 3,
            days_threshold_exceeded_count: 4,
            carryover_not_imported: true
          }
        ])
      )
    };

    const gateway = new WorkVarianceApiGateway(apiClient as never);
    const rows = await firstValueFrom(gateway.listVariancePortfolio());

    expect(apiClient.get).toHaveBeenCalledWith('/api/v1/work/variance_portfolio');
    expect(rows).toEqual([
      {
        farmId: 1,
        farmName: 'Farm A',
        planId: 10,
        planYear: 2026,
        status: 'completed',
        unrecordedCount: 2,
        gddDelayCount: 1,
        thresholdExceededCount: 3,
        daysThresholdExceededCount: 4,
        carryoverNotImported: true
      }
    ]);
  });
});
