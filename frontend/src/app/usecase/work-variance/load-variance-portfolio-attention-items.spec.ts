import { describe, expect, it, vi } from 'vitest';
import { of } from 'rxjs';
import { firstValueFrom } from 'rxjs';

import { loadVariancePortfolioAttentionItems } from './load-variance-portfolio-attention-items';
import type { VariancePortfolioRow } from '../../domain/work-variance-portfolio/variance-portfolio-row';

function row(overrides: Partial<VariancePortfolioRow> = {}): VariancePortfolioRow {
  return {
    farmId: 1,
    farmName: 'Farm A',
    planId: 10,
    planYear: 2026,
    status: 'completed',
    unrecordedCount: 0,
    gddDelayCount: 0,
    thresholdExceededCount: 0,
    daysThresholdExceededCount: 0,
    carryoverNotImported: false,
    ...overrides
  };
}

describe('loadVariancePortfolioAttentionItems', () => {
  it('builds attention list across multiple plans within farms', async () => {
    const planGateway = {
      getPlanVsActualSummary: vi.fn((planId: number) =>
        of({
          action_required_items:
            planId === 10
              ? [
                  {
                    item_id: 1,
                    field_cultivation_id: 1,
                    category: 'general',
                    name: 'Plan A task',
                    scheduled_date: '2026-06-01',
                    actual_date: '2026-06-08',
                    delta_days: 7,
                    gdd_trigger: 100,
                    gdd_at_actual: 110,
                    gdd_delta: 10,
                    exceedance_kind: 'days'
                  }
                ]
              : [
                  {
                    item_id: 2,
                    field_cultivation_id: 2,
                    category: 'general',
                    name: 'Plan B task',
                    scheduled_date: '2026-06-01',
                    actual_date: '2026-06-10',
                    delta_days: 9,
                    gdd_trigger: 100,
                    gdd_at_actual: 120,
                    gdd_delta: 20,
                    exceedance_kind: 'both'
                  }
                ]
        })
      )
    };

    const attention = await firstValueFrom(
      loadVariancePortfolioAttentionItems(
        [
          row({ planId: 10, thresholdExceededCount: 1 }),
          row({ planId: 11, farmId: 1, thresholdExceededCount: 1 })
        ],
        planGateway as never
      )
    );

    expect(planGateway.getPlanVsActualSummary).toHaveBeenCalledTimes(2);
    expect(attention.items).toHaveLength(2);
    expect(attention.items[0]?.taskName).toBe('Plan B task');
    expect(attention.items[1]?.taskName).toBe('Plan A task');
  });

  it('skips plan gateway calls when no rows need attention', async () => {
    const planGateway = { getPlanVsActualSummary: vi.fn() };

    const attention = await firstValueFrom(
      loadVariancePortfolioAttentionItems([row()], planGateway as never)
    );

    expect(planGateway.getPlanVsActualSummary).not.toHaveBeenCalled();
    expect(attention.items).toEqual([]);
  });
});
