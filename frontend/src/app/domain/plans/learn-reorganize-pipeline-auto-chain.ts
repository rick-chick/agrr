import { buildPlanDetailAdjustNavigation } from './learn-master-update-orchestration';
import type { ReorganizePipelinePhase } from './learn-master-update-orchestration';
import {
  readLearnOrchestrationProgress,
  updateLearnOrchestrationProgress
} from './learn-reorganize-pipeline-state';

export function storeLearnReorganizePipelineAutoChain(planId: number): void {
  updateLearnOrchestrationProgress(planId, {
    pipeline_active: true,
    pipeline_phase: 'placement',
    pipeline_failed_phase: null,
    pipeline_error: null
  });
}

export function readLearnReorganizePipelineAutoChain(planId: number): boolean {
  return readLearnOrchestrationProgress(planId).pipeline_active === true;
}

export function clearLearnReorganizePipelineAutoChain(planId: number): void {
  updateLearnOrchestrationProgress(planId, {
    pipeline_active: false,
    pipeline_phase: null,
    pipeline_failed_phase: null,
    pipeline_error: null
  });
}

export function setLearnReorganizePipelinePhase(
  planId: number,
  phase: ReorganizePipelinePhase
): void {
  updateLearnOrchestrationProgress(planId, {
    pipeline_active: true,
    pipeline_phase: phase,
    pipeline_failed_phase: null,
    pipeline_error: null
  });
}

export function reportLearnReorganizePipelineFailure(
  planId: number,
  failedPhase: ReorganizePipelinePhase,
  errorMessage: string
): void {
  updateLearnOrchestrationProgress(planId, {
    pipeline_active: false,
    pipeline_phase: null,
    pipeline_failed_phase: failedPhase,
    pipeline_error: errorMessage
  });
}

export function clearLearnReorganizePipelineFailure(planId: number): void {
  updateLearnOrchestrationProgress(planId, {
    pipeline_failed_phase: null,
    pipeline_error: null
  });
}

export function readLearnReorganizePipelineFailure(planId: number): {
  failedPhase: ReorganizePipelinePhase;
  errorMessage: string;
} | null {
  const progress = readLearnOrchestrationProgress(planId);
  if (!progress.pipeline_failed_phase || !progress.pipeline_error) {
    return null;
  }
  return {
    failedPhase: progress.pipeline_failed_phase,
    errorMessage: progress.pipeline_error
  };
}

export function buildLearnReorganizePipelineResumeNavigation(planId: number): {
  commands: (string | number)[];
  queryParams?: { learningOrchestration: string };
} | null {
  const progress = readLearnOrchestrationProgress(planId);
  if (!progress.pipeline_active) {
    return null;
  }
  switch (progress.pipeline_phase) {
    case 'placement':
      return buildLearnReorganizePipelineStartNavigation(planId);
    case 'optimizing':
      return { commands: ['/plans', planId, 'optimizing'] };
    case 'regenerate':
      return buildLearnReorganizePipelineRegenerateNavigation(planId);
    case 'sync_verify':
      return buildLearnReorganizePipelineSyncVerifyNavigation(planId);
    default:
      return buildLearnReorganizePipelineStartNavigation(planId);
  }
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

export function retryLearnReorganizePipeline(planId: number): {
  commands: (string | number)[];
  queryParams?: { learningOrchestration: string };
} | null {
  const failure = readLearnReorganizePipelineFailure(planId);
  if (!failure) {
    return null;
  }
  clearLearnReorganizePipelineFailure(planId);
  setLearnReorganizePipelinePhase(planId, failure.failedPhase);
  return buildLearnReorganizePipelineResumeNavigation(planId);
}
