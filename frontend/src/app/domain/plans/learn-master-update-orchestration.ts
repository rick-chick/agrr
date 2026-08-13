import {
  readLearnProposalApplicationProgress,
  markStageGddProposalAppliedPending
} from './learn-proposal-application-progress';

export type LearningOrchestrationMode = 'adjust' | 'regenerate' | 'sync_verify';

export type LearnMasterUpdateOrchestrationStep = 'placement' | 'regenerate' | 'sync_verify';

export { markStageGddProposalAppliedPending };

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

export function learnOrchestrationReturnStorageKey(planId: number): string {
  return `agrr:learn-orchestration-return:${planId}`;
}

export function storeLearnOrchestrationReturnToLearn(planId: number): void {
  sessionStorage.setItem(learnOrchestrationReturnStorageKey(planId), 'learn');
}

export function readLearnOrchestrationReturnToLearn(planId: number): boolean {
  return sessionStorage.getItem(learnOrchestrationReturnStorageKey(planId)) === 'learn';
}

export function clearLearnOrchestrationReturnToLearn(planId: number): void {
  sessionStorage.removeItem(learnOrchestrationReturnStorageKey(planId));
}

export function learnOrchestrationStepsStorageKey(planId: number): string {
  return `agrr:learn-orchestration-steps:${planId}`;
}

export function readLearnOrchestrationCompletedSteps(
  planId: number
): LearnMasterUpdateOrchestrationStep[] {
  const raw = sessionStorage.getItem(learnOrchestrationStepsStorageKey(planId));
  if (!raw) {
    return [];
  }
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed.filter(
      (step): step is LearnMasterUpdateOrchestrationStep =>
        step === 'placement' || step === 'regenerate' || step === 'sync_verify'
    );
  } catch {
    return [];
  }
}

export function isLearnOrchestrationStepComplete(
  planId: number,
  step: LearnMasterUpdateOrchestrationStep
): boolean {
  return readLearnOrchestrationCompletedSteps(planId).includes(step);
}

export function markLearnOrchestrationStepComplete(
  planId: number,
  step: LearnMasterUpdateOrchestrationStep
): void {
  const completed = readLearnOrchestrationCompletedSteps(planId);
  if (completed.includes(step)) {
    return;
  }
  sessionStorage.setItem(
    learnOrchestrationStepsStorageKey(planId),
    JSON.stringify([...completed, step])
  );
}

export function isTaskScheduleOrchestrationReadyForReturn(
  syncState: string,
  regenerating: boolean
): boolean {
  return syncState === 'ready' && !regenerating;
}

export function ensureLearnOrchestrationReturnForTaskSchedule(planId: number): void {
  storeLearnOrchestrationReturnToLearn(planId);
}

export function completeTaskScheduleOrchestrationReturn(
  planId: number,
  mode: 'regenerate' | 'sync_verify'
): void {
  const stepKey: LearnMasterUpdateOrchestrationStep =
    mode === 'regenerate' ? 'regenerate' : 'sync_verify';
  markLearnOrchestrationStepComplete(planId, stepKey);
  clearLearnOrchestrationReturnToLearn(planId);
}

export function hasPendingMasterUpdateConfirmation(planId: number): boolean {
  const progress = readLearnProposalApplicationProgress(planId);
  return Object.values(progress).some((status) => status === 'applied_pending_confirmation');
}
