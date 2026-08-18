import { of } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { LoadPlanListUseCase } from './load-plan-list.usecase';
import { LoadPlanListOutputPort } from './load-plan-list.output-port';
import { PlanGateway } from './plan-gateway';

describe('LoadPlanListUseCase', () => {
  it('presents plans with input gap summaries from parallel fetches', async () => {
    const summary: PlanVsActualSummary = {
      plan_id: 1,
      unrecorded_count: 2,
      categories: [],
      top_variance_items: [],
      action_required_items: [
        {
          item_id: 10,
          field_cultivation_id: 1,
          category: 'general',
          name: 'Task',
          scheduled_date: '2026-06-01',
          actual_date: '2026-06-04',
          delta_days: 3,
          gdd_trigger: null,
          gdd_at_actual: null,
          gdd_delta: null,
          exceedance_kind: 'days'
        }
      ]
    };

    const planGateway: PlanGateway = {
      listPlans: () => of([{ id: 1, name: 'Plan A', status: 'active', farm_id: 3 }]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({ fields: [] } as never),
      getPlanVsActualSummary: () => of(summary),
      getWeatherRescheduleProposals: () => of([]),
      previewWeatherRescheduleProposal: () => of({} as never),
      getVarianceLearning: () => of({} as never),
      importVarianceLearning: () => of({} as never),
      patchVarianceLearningProposalProgress: () => of({} as never),
      reoptimizeVarianceLearning: () => of({ success: true, plan_id: 0, optimization_enqueued: true }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),
      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as never)
    };

    const present = vi.fn();
    const outputPort: LoadPlanListOutputPort = {
      present,
      onError: vi.fn()
    };

    const useCase = new LoadPlanListUseCase(outputPort, planGateway);
    useCase.execute();

    await vi.waitFor(() => expect(present).toHaveBeenCalled());

    expect(present).toHaveBeenCalledWith({
      plans: [
        {
          id: 1,
          name: 'Plan A',
          status: 'active',
          farm_id: 3,
          inputGap: { unrecordedCount: 2, actionRequiredCount: 1, structuredUnrecordedCount: 0, amountVarianceCount: 0 }
        }
      ]
    });
  });

  it('presents empty plans without fetching summaries', async () => {
    const getPlanVsActualSummary = vi.fn();
    const present = vi.fn();
    const planGateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({ fields: [] } as never),
      getPlanVsActualSummary,
      getWeatherRescheduleProposals: () => of([]),
      previewWeatherRescheduleProposal: () => of({} as never),
      getVarianceLearning: () => of({} as never),
      importVarianceLearning: () => of({} as never),
      patchVarianceLearningProposalProgress: () => of({} as never),
      reoptimizeVarianceLearning: () => of({ success: true, plan_id: 0, optimization_enqueued: true }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),
      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as never)
    };

    const useCase = new LoadPlanListUseCase({ present, onError: vi.fn() }, planGateway);
    useCase.execute();

    await vi.waitFor(() => expect(present).toHaveBeenCalled());
    expect(getPlanVsActualSummary).not.toHaveBeenCalled();
    expect(present).toHaveBeenCalledWith({ plans: [] });
  });
});
