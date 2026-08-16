import {
  hasLearnReorganizePipelineFailure,
  readLearnOrchestrationCurrentPhase,
  readLearnOrchestrationPipelineActive,
  readLearnOrchestrationReturnToLearn,
  type LearningOrchestrationMode
} from './learn-master-update-orchestration';

export type ReorganizeScreen = 'plan_detail' | 'plan_optimizing' | 'plan_task_schedule';

export function resolveReorganizeScreenOrchestrationMode(
  planId: number,
  screen: ReorganizeScreen
): LearningOrchestrationMode | null {
  if (hasLearnReorganizePipelineFailure(planId)) {
    return null;
  }

  const pipelineActive = readLearnOrchestrationPipelineActive(planId);
  const phase = readLearnOrchestrationCurrentPhase(planId);

  if (screen === 'plan_detail') {
    if (!pipelineActive && !readLearnOrchestrationReturnToLearn(planId)) {
      return null;
    }
    if (
      phase === 'regenerate' ||
      phase === 'sync_verify' ||
      phase === 'optimizing' ||
      phase === 'completed'
    ) {
      return null;
    }
    return 'adjust';
  }

  if (screen === 'plan_optimizing') {
    return null;
  }

  if (!pipelineActive) {
    return null;
  }
  if (phase === 'regenerate') {
    return 'regenerate';
  }
  if (phase === 'sync_verify') {
    return 'sync_verify';
  }
  return null;
}

export function shouldShowReorganizePipelineOnScreen(planId: number, screen: ReorganizeScreen): boolean {
  if (hasLearnReorganizePipelineFailure(planId)) {
    return false;
  }

  const pipelineActive = readLearnOrchestrationPipelineActive(planId);
  if (screen === 'plan_detail') {
    return resolveReorganizeScreenOrchestrationMode(planId, screen) === 'adjust';
  }
  if (screen === 'plan_optimizing') {
    return pipelineActive || readLearnOrchestrationReturnToLearn(planId);
  }
  if (screen === 'plan_task_schedule') {
    return resolveReorganizeScreenOrchestrationMode(planId, screen) != null;
  }
  return false;
}
