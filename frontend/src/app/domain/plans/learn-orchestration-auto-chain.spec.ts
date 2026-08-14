import { beforeEach, describe, expect, it } from 'vitest';
import {
  buildPlanDetailAdjustNavigation,
  buildPlanTaskScheduleOrchestrationNavigation,
  clearLearnOrchestrationProgressCache,
  markLearnOrchestrationStepComplete,
  readLearnOrchestrationStepComplete
} from './learn-master-update-orchestration';
import {
  clearLearnOrchestrationAutoChain,
  enableLearnOrchestrationAutoChain,
  isLearnOrchestrationAutoChainEnabled,
  resolveLearnOrchestrationAutoChainNavigationAfterStep
} from './learn-orchestration-auto-chain';

const PLAN_ID = 7;

describe('learn-orchestration-auto-chain', () => {
  beforeEach(() => {
    sessionStorage.clear();
    clearLearnOrchestrationProgressCache();
    clearLearnOrchestrationAutoChain();
  });

  it('tracks auto-chain flag per plan', () => {
    expect(isLearnOrchestrationAutoChainEnabled(PLAN_ID)).toBe(false);
    enableLearnOrchestrationAutoChain(PLAN_ID);
    expect(isLearnOrchestrationAutoChainEnabled(PLAN_ID)).toBe(true);
    expect(isLearnOrchestrationAutoChainEnabled(99)).toBe(false);
    clearLearnOrchestrationAutoChain(PLAN_ID);
    expect(isLearnOrchestrationAutoChainEnabled(PLAN_ID)).toBe(false);
  });

  it('navigates to regenerate after placement when auto-chain is enabled', () => {
    enableLearnOrchestrationAutoChain(PLAN_ID);
    markLearnOrchestrationStepComplete(PLAN_ID, 'placement');

    const nav = resolveLearnOrchestrationAutoChainNavigationAfterStep(PLAN_ID, 'placement');
    expect(nav).toEqual(buildPlanTaskScheduleOrchestrationNavigation(PLAN_ID, 'regenerate'));
  });

  it('navigates to sync_verify after regenerate when auto-chain is enabled', () => {
    enableLearnOrchestrationAutoChain(PLAN_ID);
    markLearnOrchestrationStepComplete(PLAN_ID, 'placement');
    markLearnOrchestrationStepComplete(PLAN_ID, 'regenerate');

    const nav = resolveLearnOrchestrationAutoChainNavigationAfterStep(PLAN_ID, 'regenerate');
    expect(nav).toEqual(buildPlanTaskScheduleOrchestrationNavigation(PLAN_ID, 'sync_verify'));
  });

  it('returns learn navigation after sync_verify and clears auto-chain', () => {
    enableLearnOrchestrationAutoChain(PLAN_ID);
    markLearnOrchestrationStepComplete(PLAN_ID, 'placement');
    markLearnOrchestrationStepComplete(PLAN_ID, 'regenerate');
    markLearnOrchestrationStepComplete(PLAN_ID, 'sync_verify');

    const nav = resolveLearnOrchestrationAutoChainNavigationAfterStep(PLAN_ID, 'sync_verify');
    expect(nav).toEqual({ commands: ['/plans', PLAN_ID, 'learn'], queryParams: {} });
    expect(isLearnOrchestrationAutoChainEnabled(PLAN_ID)).toBe(false);
  });

  it('returns null when auto-chain is disabled', () => {
    markLearnOrchestrationStepComplete(PLAN_ID, 'placement');
    expect(resolveLearnOrchestrationAutoChainNavigationAfterStep(PLAN_ID, 'placement')).toBeNull();
  });

  it('buildPlanDetailAdjustNavigation is used to start pipeline from learn', () => {
    enableLearnOrchestrationAutoChain(PLAN_ID);
    expect(buildPlanDetailAdjustNavigation(PLAN_ID)).toEqual({
      commands: ['/plans', PLAN_ID],
      queryParams: { learningOrchestration: 'adjust' }
    });
    expect(readLearnOrchestrationStepComplete(PLAN_ID, 'placement')).toBe(false);
  });
});
