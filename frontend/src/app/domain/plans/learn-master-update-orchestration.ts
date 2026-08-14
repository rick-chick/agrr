import {
  markAllConfirmedProposalsDone,
  readLearnProposalApplicationProgress
} from './learn-proposal-application-progress';

export type LearningOrchestrationMode = 'adjust' | 'regenerate' | 'sync_verify';

export type LearnOrchestrationStepKey = 'placement' | 'regenerate' | 'sync_verify';

export type LearnReorganizePipelinePhase =
  | 'idle'
  | 'placement'
  | 'optimizing'
  | 'regenerate'
  | 'sync_verify'
  | 'failed'
  | 'completed';

export interface ReorganizeOrchestrationProgress {
  placement: boolean;
  regenerate: boolean;
  sync_verify: boolean;
  return_to_learn: boolean;
  pipeline_active: boolean;
  current_phase: LearnReorganizePipelinePhase;
  last_error: string | null;
}

const defaultOrchestrationProgress = (): ReorganizeOrchestrationProgress => ({
  placement: false,
  regenerate: false,
  sync_verify: false,
  return_to_learn: false,
  pipeline_active: false,
  current_phase: 'idle',
  last_error: null
});

const orchestrationCache: Record<number, ReorganizeOrchestrationProgress> = {};

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
    ...progress,
    current_phase: progress.current_phase ?? defaultOrchestrationProgress().current_phase,
    last_error: progress.last_error ?? null,
    pipeline_active: progress.pipeline_active ?? false
  };
}

function readOrchestrationProgress(planId: number): ReorganizeOrchestrationProgress {
  return orchestrationCache[planId] ?? defaultOrchestrationProgress();
}

export function readLearnOrchestrationPipelineActive(planId: number): boolean {
  return readOrchestrationProgress(planId).pipeline_active;
}

export function readLearnOrchestrationCurrentPhase(
  planId: number
): LearnReorganizePipelinePhase {
  return readOrchestrationProgress(planId).current_phase;
}

export function readLearnOrchestrationLastError(planId: number): string | null {
  return readOrchestrationProgress(planId).last_error;
}

export function patchLearnOrchestrationProgress(
  planId: number,
  updates: Partial<ReorganizeOrchestrationProgress>
): void {
  const progress = {
    ...readOrchestrationProgress(planId),
    ...updates
  };
  writeOrchestrationProgress(planId, progress);
  syncOrchestrationUpdates(planId, updates);
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
  const progress = readOrchestrationProgress(planId);
  if (progress.pipeline_active && progress.current_phase === 'optimizing') {
    return {
      commands: ['/plans', planId, 'optimizing'],
      queryParams: { learningOrchestration: 'adjust' }
    };
  }
  if (progress.pipeline_active && progress.current_phase === 'regenerate') {
    return buildPlanTaskScheduleOrchestrationNavigation(planId, 'regenerate');
  }
  if (progress.pipeline_active && progress.current_phase === 'sync_verify') {
    return buildPlanTaskScheduleOrchestrationNavigation(planId, 'sync_verify');
  }
  if (progress.pipeline_active && progress.current_phase === 'placement') {
    return buildPlanDetailAdjustNavigation(planId);
  }

  const step = findFirstIncompleteOrchestrationStep(planId);
  if (!step) {
    return null;
  }
  if (step === 'placement') {
    return buildPlanDetailAdjustNavigation(planId);
  }
  return buildPlanTaskScheduleOrchestrationNavigation(planId, step);
}

export function hasLearnReorganizePipelineFailure(planId: number): boolean {
  const progress = readOrchestrationProgress(planId);
  return progress.pipeline_active && progress.current_phase === 'failed';
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
