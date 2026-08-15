import { firstValueFrom, of, throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';
import { PlanGateway } from '../../usecase/plans/plan-gateway';
import { loadPlanListInputGaps } from './load-plan-list-input-gaps';

function summaryForPlan(planId: number): PlanVsActualSummary {
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
              name: '追肥',
              scheduled_date: '2026-06-01',
              actual_date: '2026-06-10',
              delta_days: 5,
              gdd_trigger: 100,
              gdd_at_actual: 120,
              gdd_delta: 15,
              exceedance_kind: 'both'
            }
          ]
        : []
  };
}

function stubPlanGateway(
  getPlanVsActualSummary: PlanGateway['getPlanVsActualSummary']
): PlanGateway {
  return {
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
}

describe('loadPlanListInputGaps', () => {
  it('returns per-plan input gap counts from plan vs actual summaries', async () => {
    const planGateway = stubPlanGateway((planId) => of(summaryForPlan(planId)));

    const entries = await firstValueFrom(
      loadPlanListInputGaps(
        [
          { id: 1, name: 'Plan A', status: 'pending', farm_id: 1 },
          { id: 2, name: 'Plan B', status: 'completed', farm_id: 2 }
        ],
        planGateway
      )
    );

    expect(entries).toHaveLength(2);
    expect(entries[0]).toEqual({
      plan: { id: 1, name: 'Plan A', status: 'pending', farm_id: 1 },
      inputGap: { unrecordedCount: 3, actionRequiredCount: 0 }
    });
    expect(entries[1]).toEqual({
      plan: { id: 2, name: 'Plan B', status: 'completed', farm_id: 2 },
      inputGap: { unrecordedCount: 0, actionRequiredCount: 1 }
    });
  });

  it('returns empty array when no plans are provided', async () => {
    const getPlanVsActualSummary = vi.fn();
    const entries = await firstValueFrom(
      loadPlanListInputGaps([], stubPlanGateway(getPlanVsActualSummary))
    );

    expect(getPlanVsActualSummary).not.toHaveBeenCalled();
    expect(entries).toEqual([]);
  });

  it('keeps plan visible when summary fetch fails', async () => {
    const planGateway = stubPlanGateway((planId) =>
      planId === 1 ? throwError(() => new Error('summary failed')) : of(summaryForPlan(planId))
    );

    const entries = await firstValueFrom(
      loadPlanListInputGaps(
        [
          { id: 1, name: 'Plan A', status: 'pending', farm_id: 1 },
          { id: 2, name: 'Plan B', status: 'completed', farm_id: 2 }
        ],
        planGateway
      )
    );

    expect(entries[0]).toEqual({
      plan: { id: 1, name: 'Plan A', status: 'pending', farm_id: 1 },
      inputGap: null
    });
    expect(entries[1].inputGap).toEqual({ unrecordedCount: 0, actionRequiredCount: 1 });
  });
});
