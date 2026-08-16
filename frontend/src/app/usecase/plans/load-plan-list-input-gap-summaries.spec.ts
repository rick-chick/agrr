import { of, throwError, firstValueFrom } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { PlanGateway } from './plan-gateway';
import { loadPlanListInputGapSummaries } from './load-plan-list-input-gap-summaries';

function summaryForPlan(
  planId: number,
  overrides: Partial<PlanVsActualSummary> = {}
): PlanVsActualSummary {
  return {
    plan_id: planId,
    unrecorded_count: planId === 1 ? 3 : 0,
    categories: [],
    top_variance_items: [],
    action_required_items:
      planId === 2
        ? [
            {
              item_id: 1,
              field_cultivation_id: 10,
              category: 'general',
              name: 'Task A',
              scheduled_date: '2026-06-01',
              actual_date: '2026-06-05',
              delta_days: 4,
              gdd_trigger: null,
              gdd_at_actual: null,
              gdd_delta: null,
              exceedance_kind: 'days'
            }
          ]
        : [],
    ...overrides
  };
}

function stubPlanGateway(
  getPlanVsActualSummary: PlanGateway['getPlanVsActualSummary']
): PlanGateway {
  return {
    listPlans: () => of([]),
  getWeatherRescheduleProposals: () => of([]),
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
}

describe('loadPlanListInputGapSummaries', () => {
  it('returns per-plan unrecorded and action-required counts', async () => {
    const planGateway = stubPlanGateway((planId) => of(summaryForPlan(planId)));

    const gaps = await firstValueFrom(
      loadPlanListInputGapSummaries(
        [
          { id: 1, name: 'Plan A', status: 'active', farm_id: 1 },
          { id: 2, name: 'Plan B', status: 'active', farm_id: 2 }
        ],
        planGateway
      )
    );

    expect(gaps.get(1)).toEqual({
      unrecordedCount: 3,
      actionRequiredCount: 0,
      structuredUnrecordedCount: 0,
      amountVarianceCount: 0
    });
    expect(gaps.get(2)).toEqual({
      unrecordedCount: 0,
      actionRequiredCount: 1,
      structuredUnrecordedCount: 0,
      amountVarianceCount: 0
    });
  });

  it('returns empty map when plan list is empty', async () => {
    const getPlanVsActualSummary = vi.fn();
    const gaps = await firstValueFrom(
      loadPlanListInputGapSummaries([], stubPlanGateway(getPlanVsActualSummary))
    );

    expect(getPlanVsActualSummary).not.toHaveBeenCalled();
    expect(gaps.size).toBe(0);
  });

  it('defaults to zero counts when summary fetch fails', async () => {
    const planGateway = stubPlanGateway(() => throwError(() => new Error('network')));

    const gaps = await firstValueFrom(
      loadPlanListInputGapSummaries(
        [{ id: 9, name: 'Plan', status: 'active', farm_id: 1 }],
        planGateway
      )
    );

    expect(gaps.get(9)).toEqual({
      unrecordedCount: 0,
      actionRequiredCount: 0,
      structuredUnrecordedCount: 0,
      amountVarianceCount: 0
    });
  });
});
