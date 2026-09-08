import { describe, it, expect } from 'vitest';
import type { PlanListPlan } from './plan-list-plan';
import {
  planListCardTitle,
  shouldShowCustomPlanName,
  sortPlansForList
} from './plan-list-display';

const plan = (overrides: Partial<PlanListPlan> = {}): PlanListPlan => ({
  id: 1,
  name: 'Plan A',
  status: 'pending',
  farm_id: 1,
  farm_name: 'Farm A',
  plan_year: 2026,
  inputGap: null,
  ...overrides
});

describe('planListCardTitle', () => {
  it('returns farm_name when present', () => {
    expect(planListCardTitle(plan({ farm_name: 'test' }), 'Farm #1')).toBe('test');
  });

  it('falls back to provided label when farm_name is missing', () => {
    expect(planListCardTitle(plan({ farm_id: 7, farm_name: undefined }), '農場 #7')).toBe('農場 #7');
  });
});

describe('shouldShowCustomPlanName', () => {
  it('returns false when plan name equals farm name', () => {
    expect(shouldShowCustomPlanName(plan({ farm_name: 'test', name: 'test' }))).toBe(false);
  });

  it('returns false for default Japanese farm plan suffix', () => {
    expect(
      shouldShowCustomPlanName(plan({ farm_name: '和歌山', name: '和歌山の計画' }))
    ).toBe(false);
  });

  it('returns false for legacy year suffix on farm name', () => {
    expect(
      shouldShowCustomPlanName(plan({ farm_name: 'Farm A', name: 'Farm A (2024)' }))
    ).toBe(false);
  });

  it('returns true for custom plan names', () => {
    expect(
      shouldShowCustomPlanName(plan({ farm_name: '和歌山', name: 'メイン計画' }))
    ).toBe(true);
  });

  it('returns false when plan name is empty', () => {
    expect(shouldShowCustomPlanName(plan({ farm_name: 'Farm A', name: '' }))).toBe(false);
  });
});

describe('sortPlansForList', () => {
  it('sorts by farm name ascending', () => {
    const sorted = sortPlansForList([
      plan({ id: 1, farm_id: 2, farm_name: 'Z Farm' }),
      plan({ id: 2, farm_id: 1, farm_name: 'A Farm' })
    ]);

    expect(sorted.map((p) => p.farm_name)).toEqual(['A Farm', 'Z Farm']);
  });

  it('sorts plans within the same farm by plan_year descending then id', () => {
    const sorted = sortPlansForList([
      plan({ id: 1, farm_id: 1, farm_name: 'A Farm', plan_year: 2025 }),
      plan({ id: 2, farm_id: 1, farm_name: 'A Farm', plan_year: 2026 }),
      plan({ id: 3, farm_id: 1, farm_name: 'A Farm', plan_year: null })
    ]);

    expect(sorted.map((p) => p.id)).toEqual([2, 1, 3]);
  });

  it('returns empty array for no plans', () => {
    expect(sortPlansForList([])).toEqual([]);
  });
});
