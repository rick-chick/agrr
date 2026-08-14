import {
  markAllConfirmedProposalsDone,
  readLearnProposalApplicationProgress
} from './learn-proposal-application-progress';
import {
  readLearnOrchestrationProgress,
  updateLearnOrchestrationProgress
} from './learn-reorganize-pipeline-state';

export type LearningOrchestrationMode = 'adjust' | 'regenerate' | 'sync_verify';

export type LearnOrchestrationStepKey = 'placement' | 'regenerate' | 'sync_verify';

export type ReorganizePipelinePhase = 'placement' | 'optimizing' | 'regenerate' | 'sync_verify';

export interface ReorganizeOrchestrationProgress {
  placement: boolean;
  regenerate: boolean;
  sync_verify: boolean;
  return_to_learn: boolean;
  pipeline_active?: boolean;
  pipeline_phase?: ReorganizePipelinePhase | null;
  pipeline_failed_phase?: ReorganizePipelinePhase | null;
  pipeline_error?: string | null;
}

export {
  clearLearnOrchestrationProgressCache,
  hydrateLearnOrchestrationProgress,
  registerLearnOrchestrationProgressPatchHandler
} from './learn-reorganize-pipeline-state';

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
  updateLearnOrchestrationProgress(planId, { return_to_learn: true });
}

export function readLearnOrchestrationReturnToLearn(planId: number): boolean {
  return readLearnOrchestrationProgress(planId).return_to_learn;
}

export function clearLearnOrchestrationReturnToLearn(planId: number): void {
  updateLearnOrchestrationProgress(planId, { return_to_learn: false });
}

export function markLearnOrchestrationStepComplete(
  planId: number,
  step: LearnOrchestrationStepKey
): void {
  updateLearnOrchestrationProgress(planId, { [step]: true });
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
  return readLearnOrchestrationProgress(planId)[step];
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
