import { describe, expect, it } from 'vitest';

import {
  buildWorkHubAttentionList,
  type HubFarmAttentionSource,
  type WorkHubVarianceAttentionItem
} from './build-work-hub-attention-list';
import type { PlanVarianceActionItem } from '../plans/plan-vs-actual-summary';

function actionItem(
  overrides: Partial<PlanVarianceActionItem> = {}
): PlanVarianceActionItem {
  return {
    item_id: overrides.item_id ?? 1,
    field_cultivation_id: overrides.field_cultivation_id ?? 10,
    category: overrides.category ?? 'general',
    name: overrides.name ?? '除草',
    scheduled_date: overrides.scheduled_date ?? '2026-06-01',
    actual_date: overrides.actual_date ?? '2026-06-08',
    delta_days: overrides.delta_days ?? 3,
    gdd_trigger: overrides.gdd_trigger ?? 100,
    gdd_at_actual: overrides.gdd_at_actual ?? 110,
    gdd_delta: overrides.gdd_delta ?? 10,
    exceedance_kind: overrides.exceedance_kind ?? 'days'
  };
}

function source(
  overrides: Partial<HubFarmAttentionSource> & Pick<HubFarmAttentionSource, 'farmId' | 'farmName' | 'planId'>
): HubFarmAttentionSource {
  return {
    actionItems: overrides.actionItems ?? [],
    ...overrides
  };
}

describe('buildWorkHubAttentionList', () => {
  it('returns top K action items across farms sorted by variance magnitude', () => {
    const list = buildWorkHubAttentionList(
      [
        source({
          farmId: 1,
          farmName: 'Farm A',
          planId: 9,
          actionItems: [
            actionItem({ item_id: 1, name: '小遅延', delta_days: 2, exceedance_kind: 'days' }),
            actionItem({
              item_id: 2,
              name: '大遅延',
              delta_days: 8,
              exceedance_kind: 'both',
              gdd_delta: 20
            })
          ]
        }),
        source({
          farmId: 2,
          farmName: 'Farm B',
          planId: 10,
          actionItems: [
            actionItem({
              item_id: 3,
              name: '中遅延',
              delta_days: 5,
              exceedance_kind: 'gdd',
              gdd_delta: 15
            })
          ]
        })
      ],
      [],
      2
    );

    expect(list.items).toHaveLength(2);
    const first = list.items[0] as WorkHubVarianceAttentionItem;
    const second = list.items[1] as WorkHubVarianceAttentionItem;
    expect(first.taskName).toBe('大遅延');
    expect(first.farmName).toBe('Farm A');
    expect(first.planId).toBe(9);
    expect(first.kind).toBe('variance');
    expect(first.linkTarget).toBe('learn');
    expect(second.taskName).toBe('中遅延');
    expect(second.linkTarget).toBe('learn');
  });

  it('defaults to top 5 items', () => {
    const list = buildWorkHubAttentionList([
      source({
        farmId: 1,
        farmName: 'Farm A',
        planId: 9,
        actionItems: Array.from({ length: 7 }, (_, index) =>
          actionItem({ item_id: index + 1, delta_days: index })
        )
      })
    ]);

    expect(list.items).toHaveLength(5);
  });

  it('assigns work link for days-only items and learn for gdd/both', () => {
    const list = buildWorkHubAttentionList([
      source({
        farmId: 1,
        farmName: 'Farm A',
        planId: 9,
        actionItems: [
          actionItem({ item_id: 1, exceedance_kind: 'days' }),
          actionItem({ item_id: 2, exceedance_kind: 'gdd' }),
          actionItem({ item_id: 3, exceedance_kind: 'both' })
        ]
      })
    ]);

    expect(list.items.find((item) => item.itemId === 1)?.linkTarget).toBe('work');
    expect(list.items.find((item) => item.itemId === 2)?.linkTarget).toBe('learn');
    expect(list.items.find((item) => item.itemId === 3)?.linkTarget).toBe('learn');
  });

  it('returns empty list when no action items exist', () => {
    expect(buildWorkHubAttentionList([]).items).toEqual([]);
  });

  it('includes weather trigger rows with type badges and work link', () => {
    const list = buildWorkHubAttentionList(
      [],
      [
        {
          farmId: 1,
          farmName: 'Farm A',
          planId: 9,
          count: 2,
          triggerTypes: ['frost_forecast', 'gdd_trajectory_delay']
        }
      ]
    );

    expect(list.items).toEqual([
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

  it('merges weather trigger rows with variance items by priority', () => {
    const list = buildWorkHubAttentionList(
      [
        source({
          farmId: 1,
          farmName: 'Farm A',
          planId: 9,
          actionItems: [actionItem({ item_id: 1, name: '小遅延', delta_days: 1 })]
        })
      ],
      [
        {
          farmId: 2,
          farmName: 'Farm B',
          planId: 10,
          count: 5,
          triggerTypes: ['forecast_sudden_change']
        }
      ],
      2
    );

    expect(list.items).toHaveLength(2);
    expect(list.items[0]?.kind).toBe('weather_trigger');
    expect(list.items[0]?.planId).toBe(10);
    expect(list.items[1]?.kind).toBe('variance');
  });
});
