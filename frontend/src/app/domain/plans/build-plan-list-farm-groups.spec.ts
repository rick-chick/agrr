import { describe, it, expect } from 'vitest';
import type { PlanListPlan } from './plan-list-plan';
import { buildPlanListFarmGroups } from './build-plan-list-farm-groups';

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

describe('buildPlanListFarmGroups', () => {
  it('groups plans by farm_id with farm_name header', () => {
    const groups = buildPlanListFarmGroups([
      plan({ id: 1, farm_id: 1, farm_name: 'Farm A', plan_year: 2025 }),
      plan({ id: 2, farm_id: 1, farm_name: 'Farm A', plan_year: 2026 }),
      plan({ id: 3, farm_id: 2, farm_name: 'Farm B', plan_year: 2024 })
    ]);

    expect(groups).toHaveLength(2);
    expect(groups[0]).toEqual({
      farmId: 1,
      farmName: 'Farm A',
      plans: [
        plan({ id: 2, farm_id: 1, farm_name: 'Farm A', plan_year: 2026 }),
        plan({ id: 1, farm_id: 1, farm_name: 'Farm A', plan_year: 2025 })
      ]
    });
    expect(groups[1]).toEqual({
      farmId: 2,
      farmName: 'Farm B',
      plans: [plan({ id: 3, farm_id: 2, farm_name: 'Farm B', plan_year: 2024 })]
    });
  });

  it('sorts groups by farm name and plans by plan_year descending', () => {
    const groups = buildPlanListFarmGroups([
      plan({ id: 1, farm_id: 2, farm_name: 'Z Farm', plan_year: 2020 }),
      plan({ id: 2, farm_id: 1, farm_name: 'A Farm', plan_year: null }),
      plan({ id: 3, farm_id: 1, farm_name: 'A Farm', plan_year: 2026 })
    ]);

    expect(groups.map((g) => g.farmName)).toEqual(['A Farm', 'Z Farm']);
    expect(groups[0].plans.map((p) => p.id)).toEqual([3, 2]);
  });

  it('falls back to farm id label when farm_name is missing', () => {
    const groups = buildPlanListFarmGroups([
      plan({ id: 1, farm_id: 7, farm_name: undefined, name: 'P' })
    ]);

    expect(groups[0].farmName).toBe('Farm #7');
  });

  it('returns empty array for no plans', () => {
    expect(buildPlanListFarmGroups([])).toEqual([]);
  });
});
