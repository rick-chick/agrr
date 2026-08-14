import {
  markAllConfirmedProposalsDone,
  readLearnProposalApplicationProgress
} from './learn-proposal-application-progress';

export type LearningOrchestrationMode = 'adjust' | 'regenerate' | 'sync_verify';

export type LearnOrchestrationStepKey = 'placement' | 'regenerate' | 'sync_verify';

export interface ReorganizeOrchestrationProgress {
  placement: boolean;
  regenerate: boolean;
  sync_verify: boolean;
  return_to_learn: boolean;
}

const defaultOrchestrationProgress = (): ReorganizeOrchestrationProgress => ({
  placement: false,
  regenerate: false,
  sync_verify: false,
  return_to_learn: false
});

const orchestrationCache: Record<number, ReorganizeOrchestrationProgress> = {};
const pipelineActiveByPlanId = new Set<number>();

type OrchestrationPatchHandler = (
  planId: number,
  updates: Partial<ReorganizeOrchestrationProgress>
) => void;

let orchestrationPatchHandler: OrchestrationPatchHandler | null = null;

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
    pipelineActiveByPlanId.clear();
    return;
  }
  delete orchestrationCache[planId];
  pipelineActiveByPlanId.delete(planId);
}

export function storeLearnOrchestrationPipelineActive(planId: number): void {
  pipelineActiveByPlanId.add(planId);
}

export function readLearnOrchestrationPipelineActive(planId: number): boolean {
  return pipelineActiveByPlanId.has(planId);
}

export function clearLearnOrchestrationPipelineActive(planId: number): void {
  pipelineActiveByPlanId.delete(planId);
}

export function buildLearnOrchestrationPipelineStartNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: 'adjust' };
} {
  return buildPlanDetailAdjustNavigation(planId);
}

export function buildLearnOrchestrationPipelineRegenerateNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: LearningOrchestrationMode };
} {
  return buildPlanTaskScheduleOrchestrationNavigation(planId, 'regenerate');
}

export function buildLearnOrchestrationPipelineSyncVerifyNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: LearningOrchestrationMode };
} {
  return buildPlanTaskScheduleOrchestrationNavigation(planId, 'sync_verify');
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

function readOrchestrationProgress(planId: number): ReorganizeOrchestrationProgress {
  return orchestrationCache[planId] ?? defaultOrchestrationProgress();
}

function writeOrchestrationProgress(
  planId: number,
  progress: ReorganizeOrchestrationProgress
): void {
  orchestrationCache[planId] = progress;
}

function syncOrchestrationUpdates(
  planId: number,
  updates: Partial<ReorganizeOrchestrationProgress>
): void {
  if (orchestrationPatchHandler && Object.keys(updates).length > 0) {
    orchestrationPatchHandler(planId, updates);
  }
}

export function parseLearningOrchestration(
  raw: string | null | undefined
): LearningOrchestrationMode | null {
  if (raw === 'adjust' || raw === 'regenerate' || raw === 'sync_verify') {
    return raw;
  }
  return null;
}

export function buildLearningOrchestrationNavigation(
  planId: number,
  mode: LearningOrchestrationMode
): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: LearningOrchestrationMode };
} {
  if (mode === 'adjust') {
    return buildPlanDetailAdjustNavigation(planId);
  }
  return buildPlanTaskScheduleOrchestrationNavigation(planId, mode);
}

export function buildPlanDetailAdjustNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: 'adjust' };
} {
  return {
    commands: ['/plans', planId],
    queryParams: { learningOrchestration: 'adjust' }
  };
}

export function buildPlanTaskScheduleOrchestrationNavigation(
  planId: number,
  mode: 'regenerate' | 'sync_verify'
): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: 'regenerate' | 'sync_verify' };
} {
  return {
    commands: ['/plans', planId, 'task_schedule'],
    queryParams: { learningOrchestration: mode }
  };
}

export function storeLearnOrchestrationReturnToLearn(planId: number): void {
  const progress = readOrchestrationProgress(planId);
  progress.return_to_learn = true;
  writeOrchestrationProgress(planId, progress);
  syncOrchestrationUpdates(planId, { return_to_learn: true });
}

export function readLearnOrchestrationReturnToLearn(planId: number): boolean {
  return readOrchestrationProgress(planId).return_to_learn;
}

export function clearLearnOrchestrationReturnToLearn(planId: number): void {
  const progress = readOrchestrationProgress(planId);
  progress.return_to_learn = false;
  writeOrchestrationProgress(planId, progress);
  syncOrchestrationUpdates(planId, { return_to_learn: false });
}

export function markLearnOrchestrationStepComplete(
  planId: number,
  step: LearnOrchestrationStepKey
): void {
  const progress = readOrchestrationProgress(planId);
  progress[step] = true;
  writeOrchestrationProgress(planId, progress);
  syncOrchestrationUpdates(planId, { [step]: true });
  if (areAllLearnOrchestrationStepsComplete(planId)) {
    markAllConfirmedProposalsDone(planId);
  }
}

export function areAllLearnOrchestrationStepsComplete(planId: number): boolean {
  return (
    readLearnOrchestrationStepComplete(planId, 'placement') &&
    readLearnOrchestrationStepComplete(planId, 'regenerate') &&
    readLearnOrchestrationStepComplete(planId, 'sync_verify')
  );
}

export function readLearnOrchestrationStepComplete(
  planId: number,
  step: LearnOrchestrationStepKey
): boolean {
  return readOrchestrationProgress(planId)[step];
}

export function findFirstIncompleteOrchestrationStep(
  planId: number
): LearnOrchestrationStepKey | null {
  const steps: LearnOrchestrationStepKey[] = ['placement', 'regenerate', 'sync_verify'];
  return steps.find((step) => !readLearnOrchestrationStepComplete(planId, step)) ?? null;
}

export function buildLearnOrchestrationResumeNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: string };
} | null {
  const step = findFirstIncompleteOrchestrationStep(planId);
  if (!step) {
    return null;
  }
  if (step === 'placement') {
    return buildPlanDetailAdjustNavigation(planId);
  }
  return buildPlanTaskScheduleOrchestrationNavigation(planId, step);
}

export function isTaskScheduleOrchestrationComplete(
  mode: 'regenerate' | 'sync_verify',
  syncState: string | null,
  regenerating: boolean
): boolean {
  void mode;
  return syncState === 'ready' && !regenerating;
}

export function hasPendingMasterUpdateConfirmation(planId: number): boolean {
  const progress = readLearnProposalApplicationProgress(planId);
  return Object.values(progress).some((status) => status === 'applied_pending_confirmation');
}

export function hasActiveLearnMasterUpdateFlow(planId: number): boolean {
  const progress = readLearnProposalApplicationProgress(planId);
  return Object.values(progress).some(
    (status) => status === 'applied_pending_confirmation' || status === 'confirmed'
  );
}
