import { describe, expect, it } from 'vitest';
import type { PlanVarianceActionItem } from '../plans/plan-vs-actual-summary';
import {
  DEFAULT_WORK_HUB_ATTENTION_LIMIT,
  buildWorkHubAttentionList,
  resolveWorkHubAttentionLinkTarget
} from './build-work-hub-attention-list';

function actionItem(
  overrides: Partial<PlanVarianceActionItem> & Pick<PlanVarianceActionItem, 'item_id' | 'name'>
): PlanVarianceActionItem {
  return {
    field_cultivation_id: 10,
    category: 'general',
    scheduled_date: '2026-06-01',
    actual_date: '2026-06-10',
    delta_days: 5,
    gdd_trigger: 100,
    gdd_at_actual: 120,
    gdd_delta: 15,
    exceedance_kind: 'both',
    ...overrides
  };
}

describe('resolveWorkHubAttentionLinkTarget', () => {
  it('routes days-only exceedance to learn', () => {
    expect(
      resolveWorkHubAttentionLinkTarget(
        actionItem({ item_id: 1, name: 'A', exceedance_kind: 'days' })
      )
    ).toBe('learn');
  });

  it('routes gdd exceedance to work', () => {
    expect(
      resolveWorkHubAttentionLinkTarget(
        actionItem({ item_id: 1, name: 'A', exceedance_kind: 'gdd' })
      )
    ).toBe('work');
  });

  it('routes both exceedance to work', () => {
    expect(
      resolveWorkHubAttentionLinkTarget(
        actionItem({ item_id: 1, name: 'A', exceedance_kind: 'both' })
      )
    ).toBe('work');
  });
});

describe('buildWorkHubAttentionList', () => {
  it('returns empty list when no farms have action items', () => {
    expect(
      buildWorkHubAttentionList([
        { farmId: 1, farmName: 'Farm A', planId: 9, actionItems: [] }
      ])
    ).toEqual([]);
  });

  it('returns top K action items across farms with farm name and link target', () => {
    const items = buildWorkHubAttentionList(
      [
        {
          farmId: 1,
          farmName: 'Farm A',
          planId: 9,
          actionItems: [
            actionItem({
              item_id: 1,
              name: 'Low priority',
              exceedance_kind: 'days',
              delta_days: 1,
              gdd_delta: 1
            }),
            actionItem({
              item_id: 2,
              name: 'High priority',
              exceedance_kind: 'both',
              delta_days: 10,
              gdd_delta: 20
            })
          ]
        },
        {
          farmId: 2,
          farmName: 'Farm B',
          planId: 10,
          actionItems: [
            actionItem({
              item_id: 3,
              name: 'Mid priority',
              exceedance_kind: 'gdd',
              delta_days: 5,
              gdd_delta: 12
            })
          ]
        }
      ],
      2
    );

    expect(items).toHaveLength(2);
    expect(items[0]).toEqual({
      farmId: 1,
      farmName: 'Farm A',
      planId: 9,
      itemId: 2,
      taskName: 'High priority',
      linkTarget: 'work'
    });
    expect(items[1]).toEqual({
      farmId: 2,
      farmName: 'Farm B',
      planId: 10,
      itemId: 3,
      taskName: 'Mid priority',
      linkTarget: 'work'
    });
  });

  it('defaults to top five items', () => {
    const farms = Array.from({ length: 6 }, (_, index) => ({
      farmId: index + 1,
      farmName: `Farm ${index + 1}`,
      planId: index + 1,
      actionItems: [
        actionItem({
          item_id: index + 1,
          name: `Task ${index + 1}`,
          exceedance_kind: 'both',
          delta_days: index + 1,
          gdd_delta: index + 1
        })
      ]
    }));

    expect(buildWorkHubAttentionList(farms)).toHaveLength(DEFAULT_WORK_HUB_ATTENTION_LIMIT);
  });
});
