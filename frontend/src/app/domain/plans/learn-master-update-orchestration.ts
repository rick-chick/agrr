import {
  readLearnProposalApplicationProgress,
  markStageGddProposalAppliedPending
} from './learn-proposal-application-progress';

export type LearningOrchestrationMode = 'adjust' | 'regenerate' | 'sync_verify';

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

export function hasPendingMasterUpdateConfirmation(planId: number): boolean {
  const progress = readLearnProposalApplicationProgress(planId);
  return Object.values(progress).some((status) => status === 'applied_pending_confirmation');
}
