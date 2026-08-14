import type {
  ReorganizeOrchestrationProgress,
  ReorganizePipelinePhase
} from './learn-master-update-orchestration';

const orchestrationCache: Record<number, ReorganizeOrchestrationProgress> = {};

type OrchestrationPatchHandler = (
  planId: number,
  updates: Partial<ReorganizeOrchestrationProgress>
) => void;

let orchestrationPatchHandler: OrchestrationPatchHandler | null = null;

const defaultOrchestrationProgress = (): ReorganizeOrchestrationProgress => ({
  placement: false,
  regenerate: false,
  sync_verify: false,
  return_to_learn: false,
  pipeline_active: false,
  pipeline_phase: null,
  pipeline_failed_phase: null,
  pipeline_error: null
});

export function registerLearnOrchestrationProgressPatchHandler(
  handler: OrchestrationPatchHandler
): void {
  orchestrationPatchHandler = handler;
}

export function clearLearnOrchestrationProgressCache(planId?: number): void {
  if (planId == null) {
    for (const key of Object.keys(orchestrationCache)) {
      delete orchestrationCache[Number(key)];
    }
    return;
  }
  delete orchestrationCache[planId];
}

export function hydrateLearnOrchestrationProgress(
  planId: number,
  progress: Partial<ReorganizeOrchestrationProgress>
): void {
  orchestrationCache[planId] = {
    ...defaultOrchestrationProgress(),
    ...progress
  };
}

export function readLearnOrchestrationProgress(planId: number): ReorganizeOrchestrationProgress {
  return orchestrationCache[planId] ?? defaultOrchestrationProgress();
}

export function updateLearnOrchestrationProgress(
  planId: number,
  updates: Partial<ReorganizeOrchestrationProgress>
): void {
  const next = {
    ...readLearnOrchestrationProgress(planId),
    ...updates
  };
  orchestrationCache[planId] = next;
  syncLearnOrchestrationUpdates(planId, updates);
}

export function syncLearnOrchestrationUpdates(
  planId: number,
  updates: Partial<ReorganizeOrchestrationProgress>
): void {
  if (orchestrationPatchHandler && Object.keys(updates).length > 0) {
    orchestrationPatchHandler(planId, updates);
  }
}

export type { ReorganizePipelinePhase };
