import { firstValueFrom, of } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import type { PlanGateway } from '../plans/plan-gateway';
import { loadHubFarmAttentionItems } from './load-hub-farm-attention-items';

describe('loadHubFarmAttentionItems', () => {
  it('returns empty list when no farms have plans', async () => {
    const planGateway = {
      getPlanVsActualSummary: vi.fn()
    } as unknown as PlanGateway;

    const attentionList = await firstValueFrom(
      loadHubFarmAttentionItems([{ farmId: 1, farmName: 'Farm A', planId: null }], planGateway)
    );

    expect(attentionList).toEqual({ items: [] });
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

    const attentionList = await firstValueFrom(
      loadHubFarmAttentionItems(
        [
          { farmId: 1, farmName: 'Farm A', planId: 9 },
          { farmId: 2, farmName: 'Farm B', planId: 10 }
        ],
        planGateway
      )
    );

    expect(attentionList).toEqual({
      items: [
        {
          kind: 'variance',
          farmId: 1,
          farmName: 'Farm A',
          planId: 9,
          itemId: 1,
          taskName: 'Farm A task',
          linkTarget: 'learn'
        },
        {
          kind: 'variance',
          farmId: 2,
          farmName: 'Farm B',
          planId: 10,
          itemId: 2,
          taskName: 'Farm B task',
          linkTarget: 'work'
        }
      ]
    });
  });

  it('merges weather trigger rows from portfolio counts and proposal types', async () => {
    const planGateway = {
      getPlanVsActualSummary: () =>
        of({
          plan_id: 9,
          unrecorded_count: 0,
          categories: [],
          top_variance_items: [],
          action_required_items: []
        }),
      getWeatherRescheduleProposals: () =>
        of([
          {
            id: 'frost_forecast:100:42',
            trigger_type: 'frost_forecast',
            severity: 'high',
            rationale: {},
            moves: []
          },
          {
            id: 'gdd_trajectory_delay:100:43',
            trigger_type: 'gdd_trajectory_delay',
            severity: 'medium',
            rationale: {},
            moves: []
          }
        ])
    } as unknown as PlanGateway;

    const attentionList = await firstValueFrom(
      loadHubFarmAttentionItems(
        [{ farmId: 1, farmName: 'Farm A', planId: 9 }],
        planGateway,
        [
          {
            farmId: 1,
            farmName: 'Farm A',
            planId: 9,
            planYear: 2026,
            status: 'completed',
            unrecordedCount: 0,
            gddDelayCount: 0,
            thresholdExceededCount: 0,
            daysThresholdExceededCount: 0,
            carryoverNotImported: false,
            weatherTriggerCount: 2
          }
        ]
      )
    );

    expect(attentionList.items).toEqual([
      {
        kind: 'weather_trigger',
        farmId: 1,
        farmName: 'Farm A',
        planId: 9,
        itemId: -9,
        weatherTriggerCount: 2,
        weatherTriggerTypes: ['frost_forecast', 'gdd_trajectory_delay'],
        linkTarget: 'work'
      }
    ]);
  });
});
