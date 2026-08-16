import { describe, expect, it, beforeEach } from 'vitest';
import {
  clearLearnOrchestrationProgressCache,
  hydrateLearnOrchestrationProgress
} from './learn-master-update-orchestration';
import {
  resolveReorganizeScreenOrchestrationMode,
  shouldShowReorganizePipelineOnScreen
} from './resolve-reorganize-screen-orchestration-mode';

const PLAN_ID = 42;

describe('resolveReorganizeScreenOrchestrationMode', () => {
  beforeEach(() => {
    clearLearnOrchestrationProgressCache();
  });

  it('returns adjust for plan detail when pipeline is at placement phase', () => {
    hydrateLearnOrchestrationProgress(PLAN_ID, {
      pipeline_active: true,
      current_phase: 'placement'
    });

    expect(resolveReorganizeScreenOrchestrationMode(PLAN_ID, 'plan_detail')).toBe('adjust');
    expect(shouldShowReorganizePipelineOnScreen(PLAN_ID, 'plan_detail')).toBe(true);
  });

  it('returns regenerate for task schedule when pipeline is at regenerate phase', () => {
    hydrateLearnOrchestrationProgress(PLAN_ID, {
      pipeline_active: true,
      current_phase: 'regenerate'
    });

    expect(resolveReorganizeScreenOrchestrationMode(PLAN_ID, 'plan_task_schedule')).toBe(
      'regenerate'
    );
    expect(shouldShowReorganizePipelineOnScreen(PLAN_ID, 'plan_task_schedule')).toBe(true);
  });

  it('returns sync_verify for task schedule when pipeline is at sync_verify phase', () => {
    hydrateLearnOrchestrationProgress(PLAN_ID, {
      pipeline_active: true,
      current_phase: 'sync_verify'
    });

    expect(resolveReorganizeScreenOrchestrationMode(PLAN_ID, 'plan_task_schedule')).toBe(
      'sync_verify'
    );
    expect(shouldShowReorganizePipelineOnScreen(PLAN_ID, 'plan_task_schedule')).toBe(true);
  });

  it('shows optimizing banner after hydrate when pipeline is optimizing', () => {
    hydrateLearnOrchestrationProgress(PLAN_ID, {
      pipeline_active: true,
      current_phase: 'optimizing'
    });

    expect(shouldShowReorganizePipelineOnScreen(PLAN_ID, 'plan_optimizing')).toBe(true);
    expect(resolveReorganizeScreenOrchestrationMode(PLAN_ID, 'plan_detail')).toBeNull();
  });

  it('returns null when pipeline failed', () => {
    hydrateLearnOrchestrationProgress(PLAN_ID, {
      pipeline_active: true,
      current_phase: 'failed',
      last_error: 'plans.learn.pipeline_status.unknown_error'
    });

    expect(resolveReorganizeScreenOrchestrationMode(PLAN_ID, 'plan_detail')).toBeNull();
    expect(shouldShowReorganizePipelineOnScreen(PLAN_ID, 'plan_optimizing')).toBe(false);
  });
});
