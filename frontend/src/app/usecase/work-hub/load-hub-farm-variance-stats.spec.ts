import { of, firstValueFrom } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { PlanGateway } from '../plans/plan-gateway';
import { loadHubFarmVarianceStats } from './load-hub-farm-variance-stats';

function summaryForPlan(
  planId: number,
  overrides: Partial<PlanVsActualSummary> = {}
): PlanVsActualSummary {
  return {
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
              name: '追肥',
              scheduled_date: '2026-06-01',
              actual_date: '2026-06-10',
              delta_days: 5,
              gdd_trigger: 100,
              gdd_at_actual: 120,
              gdd_delta: 15,
              exceedance_kind: 'both'
            },
            {
              item_id: 2,
              field_cultivation_id: 10,
              category: 'general',
              name: '除草',
              scheduled_date: '2026-06-02',
              actual_date: '2026-06-08',
              delta_days: 2,
              gdd_trigger: 50,
              gdd_at_actual: 65,
              gdd_delta: 12,
              exceedance_kind: 'days'
            }
          ]
        : [
            {
              item_id: 3,
              field_cultivation_id: 11,
              category: 'fertilizer',
              name: '施肥',
              scheduled_date: '2026-06-03',
              actual_date: '2026-06-10',
              delta_days: 4,
              gdd_trigger: 80,
              gdd_at_actual: 95,
              gdd_delta: 11,
              exceedance_kind: 'gdd'
            }
          ],
    ...overrides
  };
}

describe('loadHubFarmVarianceStats', () => {
  it('returns per-farm gdd delay and threshold exceeded counts', async () => {
    const planGateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({ fields: [] } as never),
      getPlanVsActualSummary: (planId) => of(summaryForPlan(planId)),
      getVarianceLearning: () =>
        of({
          plan_id: 0,
          source_plan_id: 0,
          summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }
        }),
      importVarianceLearning: () =>
        of({
          plan_id: 0,
          source_plan_id: 0,
          summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }
        }),
      patchVarianceLearningProposalProgress: () =>
        of({ plan_id: 0, proposal_application_progress: {} }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),
      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as never)
    };

    const stats = await firstValueFrom(
      loadHubFarmVarianceStats(
        [
          { farmId: 1, planId: 9 },
          { farmId: 2, planId: 10 },
          { farmId: 3, planId: null }
        ],
        planGateway
      )
    );

    expect(stats.get(1)).toEqual({
      unrecordedCount: 0,
      gddDelayCount: 1,
      daysExceedanceCount: 2,
      thresholdExceededCount: 2,
      actionItems: summaryForPlan(9).action_required_items
    });
    expect(stats.get(2)).toEqual({
      unrecordedCount: 0,
      gddDelayCount: 1,
      daysExceedanceCount: 0,
      thresholdExceededCount: 1,
      actionItems: summaryForPlan(10).action_required_items
    });
    expect(stats.get(3)).toEqual({
      unrecordedCount: 0,
      gddDelayCount: 0,
      daysExceedanceCount: 0,
      thresholdExceededCount: 0,
      actionItems: []
    });
  });

  it('returns per-farm unrecorded counts from plan summary', async () => {
    const planGateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({ fields: [] } as never),
      getPlanVsActualSummary: (planId) =>
        of(
          summaryForPlan(planId, {
            unrecorded_count: planId === 9 ? 4 : 1
          })
        ),
      getVarianceLearning: () =>
        of({
          plan_id: 0,
          source_plan_id: 0,
          summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }
        }),
      importVarianceLearning: () =>
        of({
          plan_id: 0,
          source_plan_id: 0,
          summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }
        }),
      patchVarianceLearningProposalProgress: () =>
        of({ plan_id: 0, proposal_application_progress: {} }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),
      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as never)
    };

    const stats = await firstValueFrom(
      loadHubFarmVarianceStats([{ farmId: 1, planId: 9 }, { farmId: 2, planId: 10 }], planGateway)
    );

    expect(stats.get(1)?.unrecordedCount).toBe(4);
    expect(stats.get(2)?.unrecordedCount).toBe(1);
  });

  it('returns empty map when no farms have a plan', async () => {
    const getPlanVsActualSummary = vi.fn();
    const planGateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({ fields: [] } as never),
      getPlanVsActualSummary,
      getVarianceLearning: () =>
        of({
          plan_id: 0,
          source_plan_id: 0,
          summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }
        }),
      importVarianceLearning: () =>
        of({
          plan_id: 0,
          source_plan_id: 0,
          summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }
        }),
      patchVarianceLearningProposalProgress: () =>
        of({ plan_id: 0, proposal_application_progress: {} }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),
      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as never)
    };

    const stats = await firstValueFrom(
      loadHubFarmVarianceStats(
        [
          { farmId: 1, planId: null },
          { farmId: 2, planId: null }
        ],
        planGateway
      )
    );

    expect(getPlanVsActualSummary).not.toHaveBeenCalled();
    expect(stats.size).toBe(0);
  });
});
