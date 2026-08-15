import { describe, expect, it } from 'vitest';

import { resolveVarianceActionItemLinkTarget } from './resolve-variance-action-item-link-target';
import type { PlanVarianceActionItem } from './plan-vs-actual-summary';

function actionItem(
  exceedance_kind: PlanVarianceActionItem['exceedance_kind']
): PlanVarianceActionItem {
  return {
    item_id: 1,
    field_cultivation_id: 10,
    category: 'general',
    name: '除草',
    scheduled_date: '2026-06-01',
    actual_date: '2026-06-08',
    delta_days: 3,
    gdd_trigger: 100,
    gdd_at_actual: 110,
    gdd_delta: 10,
    exceedance_kind
  };
}

describe('resolveVarianceActionItemLinkTarget', () => {
  it('routes days-only exceedance to work', () => {
    expect(resolveVarianceActionItemLinkTarget(actionItem('days'))).toBe('work');
  });

  it('routes gdd exceedance to learn', () => {
    expect(resolveVarianceActionItemLinkTarget(actionItem('gdd'))).toBe('learn');
  });

  it('routes both exceedance kinds to learn', () => {
    expect(resolveVarianceActionItemLinkTarget(actionItem('both'))).toBe('learn');
  });
});
