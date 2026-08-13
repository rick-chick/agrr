import { of, throwError } from 'rxjs';
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
    deletePlan: () => of({} as never),
    ...overrides
  };
}

describe('LoadPlanLearnCarryoverUseCase', () => {
  it('loadFarmContext returns same-farm plans excluding the current plan', (done) => {
    const useCase = new LoadPlanLearnCarryoverUseCase(createGateway());

    useCase.loadFarmContext(PLAN_ID).subscribe((plans) => {
      expect(plans).toEqual([sameFarmPlan]);
      done();
    });
  });

  it('loadFarmContext returns empty array when fetchPlan fails', (done) => {
    const gateway = createGateway({
      fetchPlan: () => throwError(() => new Error('not found'))
    });
    const useCase = new LoadPlanLearnCarryoverUseCase(gateway);

    useCase.loadFarmContext(PLAN_ID).subscribe((plans) => {
      expect(plans).toEqual([]);
      done();
    });
  });

  it('loadFarmContext returns empty array when listPlans fails', (done) => {
    const gateway = createGateway({
      listPlans: () => throwError(() => new Error('network'))
    });
    const useCase = new LoadPlanLearnCarryoverUseCase(gateway);

    useCase.loadFarmContext(PLAN_ID).subscribe((plans) => {
      expect(plans).toEqual([]);
      done();
    });
  });

  it('loadCarryoverPreview delegates to getPlanVsActualSummary', (done) => {
    const useCase = new LoadPlanLearnCarryoverUseCase(createGateway());

    useCase.loadCarryoverPreview(PLAN_ID).subscribe((result) => {
      expect(result).toEqual(summary);
      done();
    });
  });

  it('loadLearningSnapshot returns null when gateway errors', (done) => {
    const gateway = createGateway({
      getVarianceLearning: () => throwError(() => new Error('missing'))
    });
    const useCase = new LoadPlanLearnCarryoverUseCase(gateway);

    useCase.loadLearningSnapshot(PLAN_ID).subscribe((result) => {
      expect(result).toBeNull();
      done();
    });
  });

  it('importLearning delegates to importVarianceLearning with source plan id', (done) => {
    const gateway = createGateway({
      importVarianceLearning: (planId, sourcePlanId) =>
        of({ ...snapshot, plan_id: planId, source_plan_id: sourcePlanId })
    });
    const useCase = new LoadPlanLearnCarryoverUseCase(gateway);

    useCase.importLearning(PLAN_ID, 8).subscribe((result) => {
      expect(result).toEqual({ ...snapshot, plan_id: PLAN_ID, source_plan_id: 8 });
      done();
    });
  });
});
