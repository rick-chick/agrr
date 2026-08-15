import { firstValueFrom, of } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import type { PlanGateway } from '../plans/plan-gateway';
import { loadHubFarmAttentionItems } from './load-hub-farm-attention-items';

describe('loadHubFarmAttentionItems', () => {
  it('returns empty list when no farms have plans', async () => {
    const planGateway = {
      getPlanVsActualSummary: vi.fn()
    } as unknown as PlanGateway;

    const items = await firstValueFrom(
      loadHubFarmAttentionItems([{ farmId: 1, farmName: 'Farm A', planId: null }], planGateway)
    );

    expect(items).toEqual([]);
    expect(planGateway.getPlanVsActualSummary).not.toHaveBeenCalled();
  });

  it('returns top attention items across farms from action_required_items', async () => {
    const planGateway = {
      getPlanVsActualSummary: (planId: number) =>
        of({
          plan_id: planId,
          unrecorded_count: 0,
          categories: [],
          top_variance_items: [],
          action_required_items:
            planId === 9
              ? [
                  {
                    item_id: 1,
                    field_cultivation_id: 10,
                    category: 'general',
                    name: 'Farm A task',
                    scheduled_date: '2026-06-01',
                    actual_date: '2026-06-10',
                    delta_days: 5,
                    gdd_trigger: 100,
                    gdd_at_actual: 120,
                    gdd_delta: 15,
                    exceedance_kind: 'both'
                  }
                ]
              : [
                  {
                    item_id: 2,
                    field_cultivation_id: 11,
                    category: 'fertilizer',
                    name: 'Farm B task',
                    scheduled_date: '2026-06-02',
                    actual_date: '2026-06-08',
                    delta_days: 2,
                    gdd_trigger: 50,
                    gdd_at_actual: 65,
                    gdd_delta: 12,
                    exceedance_kind: 'days'
                  }
                ]
        })
    } as unknown as PlanGateway;

    const items = await firstValueFrom(
      loadHubFarmAttentionItems(
        [
          { farmId: 1, farmName: 'Farm A', planId: 9 },
          { farmId: 2, farmName: 'Farm B', planId: 10 }
        ],
        planGateway
      )
    );

    expect(items).toEqual([
      {
        farmId: 1,
        farmName: 'Farm A',
        planId: 9,
        itemId: 1,
        taskName: 'Farm A task',
        linkTarget: 'work'
      },
      {
        farmId: 2,
        farmName: 'Farm B',
        planId: 10,
        itemId: 2,
        taskName: 'Farm B task',
        linkTarget: 'learn'
      }
    ]);
  });
});
