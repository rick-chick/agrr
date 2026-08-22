import {
  buildPlanDetailAdjustNavigation,
  patchLearnOrchestrationProgress,
  readLearnOrchestrationPipelineActive,
  type LearnReorganizePipelinePhase
} from './learn-master-update-orchestration';

export function storeLearnReorganizePipelineAutoChain(planId: number): void {
  patchLearnOrchestrationProgress(planId, {
    pipeline_active: true,
    current_phase: 'placement',
    last_error: null
  });
}

export function storeLearnReorganizePipelineAutoChainSkipPlacement(planId: number): void {
  patchLearnOrchestrationProgress(planId, {
    pipeline_active: true,
    current_phase: 'optimizing',
    last_error: null
  });
}

export function readLearnReorganizePipelineAutoChain(planId: number): boolean {
  return readLearnOrchestrationPipelineActive(planId);
}

export function clearLearnReorganizePipelineAutoChain(planId?: number): void {
  if (planId == null) {
    return;
  }
  patchLearnOrchestrationProgress(planId, {
    pipeline_active: false,
    current_phase: 'completed',
    last_error: null
  });
}

export function updateLearnReorganizePipelinePhase(
  planId: number,
  phase: LearnReorganizePipelinePhase
): void {
  patchLearnOrchestrationProgress(planId, { current_phase: phase });
}

export function setLearnReorganizePipelineError(planId: number, message: string): void {
  patchLearnOrchestrationProgress(planId, {
    pipeline_active: true,
    current_phase: 'failed',
    last_error: message
  });
}

export function clearLearnReorganizePipelineError(planId: number): void {
  patchLearnOrchestrationProgress(planId, {
    last_error: null
  });
}

export function buildLearnReorganizePipelineStartNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: 'adjust' };
} {
  return buildPlanDetailAdjustNavigation(planId);
}

export function buildLearnReorganizePipelineRegenerateNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: 'regenerate' };
} {
  return {
    commands: ['/plans', planId, 'task_schedule'],
    queryParams: { learningOrchestration: 'regenerate' }
  };
}

export function buildLearnReorganizePipelineSyncVerifyNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { learningOrchestration: 'sync_verify' };
} {
  return {
    commands: ['/plans', planId, 'task_schedule'],
    queryParams: { learningOrchestration: 'sync_verify' }
  };
}
