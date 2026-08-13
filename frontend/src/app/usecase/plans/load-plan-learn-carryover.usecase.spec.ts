import { firstValueFrom, of, throwError } from 'rxjs';
import { describe, expect, it } from 'vitest';
import { LoadPlanLearnCarryoverUseCase } from './load-plan-learn-carryover.usecase';
import type { PlanGateway } from './plan-gateway';
import type { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVarianceLearningSnapshot } from '../../domain/plans/plan-variance-learning-snapshot';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';

const PLAN_ID = 7;
const FARM_ID = 3;

const currentPlan: PlanSummary = { id: PLAN_ID, name: 'Current', status: 'active', farm_id: FARM_ID };
const sameFarmPlan: PlanSummary = { id: 8, name: 'Other', status: 'active', farm_id: FARM_ID };
const otherFarmPlan: PlanSummary = { id: 9, name: 'Elsewhere', status: 'active', farm_id: 99 };

const summary: PlanVsActualSummary = {
  plan_id: PLAN_ID,
  unrecorded_count: 0,
  categories: [],
  top_variance_items: []
};

const snapshot: PlanVarianceLearningSnapshot = {
  plan_id: PLAN_ID,
  source_plan_id: 8,
  summary
};

function createGateway(overrides: Partial<PlanGateway> = {}): PlanGateway {
  return {
    listPlans: () => of([currentPlan, sameFarmPlan, otherFarmPlan]),
    fetchPlan: () => of(currentPlan),
    fetchPlanData: () => of({} as never),
    getPublicPlanData: () => of({} as never),
    getTaskSchedule: () => of({} as never),
    getPlanVsActualSummary: () => of(summary),
    getVarianceLearning: () => of(snapshot),
    importVarianceLearning: () => of(snapshot),
    regenerateTaskSchedule: () => of(undefined),

    createTaskScheduleItem: () => of({} as never),

    updateTaskScheduleItem: () => of({} as never),
    deletePlan: () => of({} as never),
    ...overrides
  };
}

describe('LoadPlanLearnCarryoverUseCase', () => {
  it('loadFarmContext returns same-farm plans excluding the current plan', async () => {
    const useCase = new LoadPlanLearnCarryoverUseCase(createGateway());

    await expect(firstValueFrom(useCase.loadFarmContext(PLAN_ID))).resolves.toEqual([sameFarmPlan]);
  });

  it('loadFarmContext returns empty array when fetchPlan fails', async () => {
    const gateway = createGateway({
      fetchPlan: () => throwError(() => new Error('not found'))
    });
    const useCase = new LoadPlanLearnCarryoverUseCase(gateway);

    await expect(firstValueFrom(useCase.loadFarmContext(PLAN_ID))).resolves.toEqual([]);
  });

  it('loadFarmContext returns empty array when listPlans fails', async () => {
    const gateway = createGateway({
      listPlans: () => throwError(() => new Error('network'))
    });
    const useCase = new LoadPlanLearnCarryoverUseCase(gateway);

    await expect(firstValueFrom(useCase.loadFarmContext(PLAN_ID))).resolves.toEqual([]);
  });

  it('loadCarryoverPreview delegates to getPlanVsActualSummary', async () => {
    const useCase = new LoadPlanLearnCarryoverUseCase(createGateway());

    await expect(firstValueFrom(useCase.loadCarryoverPreview(PLAN_ID))).resolves.toEqual(summary);
  });

  it('loadLearningSnapshot returns null when gateway errors', async () => {
    const gateway = createGateway({
      getVarianceLearning: () => throwError(() => new Error('missing'))
    });
    const useCase = new LoadPlanLearnCarryoverUseCase(gateway);

    await expect(firstValueFrom(useCase.loadLearningSnapshot(PLAN_ID))).resolves.toBeNull();
  });

  it('importLearning delegates to importVarianceLearning with source plan id', async () => {
    const gateway = createGateway({
      importVarianceLearning: (planId, sourcePlanId) =>
        of({ ...snapshot, plan_id: planId, source_plan_id: sourcePlanId })
    });
    const useCase = new LoadPlanLearnCarryoverUseCase(gateway);

    await expect(firstValueFrom(useCase.importLearning(PLAN_ID, 8))).resolves.toEqual({
      ...snapshot,
      plan_id: PLAN_ID,
      source_plan_id: 8
    });
  });
});
