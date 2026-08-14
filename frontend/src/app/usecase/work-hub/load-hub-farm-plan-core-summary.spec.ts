import { of, firstValueFrom } from 'rxjs';
import { describe, expect, it } from 'vitest';
import type { PlanVsActualSummary, VarianceExceedanceKind } from '../../domain/plans/plan-vs-actual-summary';
import { PlanGateway } from '../plans/plan-gateway';
import { loadHubFarmPlanCoreSummary } from './load-hub-farm-plan-core-summary';

function varianceSummary(
  planId: number,
  actionRequiredCount: number,
  gddDelayCount: number
): PlanVsActualSummary {
  const action_required_items = Array.from({ length: actionRequiredCount }, (_, index) => ({
    item_id: index + 1,
    field_cultivation_id: 10,
    category: 'general',
    name: `作業${index + 1}`,
    scheduled_date: '2026-06-01',
    actual_date: '2026-06-10',
    delta_days: 5,
    gdd_trigger: 100,
    gdd_at_actual: 120,
    gdd_delta: 15,
    exceedance_kind: (index < gddDelayCount ? 'gdd' : 'days') as VarianceExceedanceKind
  }));

  return {
    plan_id: planId,
    unrecorded_count: 0,
    categories: [],
    top_variance_items: [],
    action_required_items
  };
}

describe('loadHubFarmPlanCoreSummary', () => {
  it('returns per-farm gdd delay and threshold exceeded counts from plan vs actual summary', async () => {
    const planGateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({ fields: [] } as never),
      getPlanVsActualSummary: (planId) =>
        of(
          planId === 9
            ? varianceSummary(9, 2, 1)
            : varianceSummary(10, 0, 0)
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
      patchVarianceLearningProposalProgress: () => of({ plan_id: 0, proposal_application_progress: {} }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),
      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as never)
    };

    const summaries = await firstValueFrom(
      loadHubFarmPlanCoreSummary(
        [
          { farmId: 1, planId: 9 },
          { farmId: 2, planId: 10 },
          { farmId: 3, planId: null }
        ],
        planGateway
      )
    );

    expect(summaries.get(1)).toEqual({ gddDelayCount: 1, thresholdExceededCount: 2 });
    expect(summaries.get(2)).toEqual({ gddDelayCount: 0, thresholdExceededCount: 0 });
    expect(summaries.get(3)).toEqual({ gddDelayCount: 0, thresholdExceededCount: 0 });
  });

  it('returns empty map when no farms have a plan', async () => {
    const planGateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({ fields: [] } as never),
      getPlanVsActualSummary: () =>
        of({ plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }),
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
      patchVarianceLearningProposalProgress: () => of({ plan_id: 0, proposal_application_progress: {} }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),
      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as never)
    };

    const summaries = await firstValueFrom(
      loadHubFarmPlanCoreSummary(
        [
          { farmId: 1, planId: null },
          { farmId: 2, planId: null }
        ],
        planGateway
      )
    );

    expect(summaries.size).toBe(0);
  });
});
