import type { LearnReorganizePipelinePhase } from './learn-master-update-orchestration';

export type LearnReorganizePipelineStage = 'adjust' | 'optimizing' | 'task_schedule';

export function resolveLearnReorganizePipelineStage(
  phase: LearnReorganizePipelinePhase
): LearnReorganizePipelineStage | null {
  switch (phase) {
    case 'placement':
      return 'adjust';
    case 'optimizing':
      return 'optimizing';
    case 'regenerate':
    case 'sync_verify':
      return 'task_schedule';
    default:
      return null;
  }
}

export function resolveLearnReorganizePipelineStageLabelKey(
  phase: LearnReorganizePipelinePhase
): string | null {
  const stage = resolveLearnReorganizePipelineStage(phase);
  return stage ? `plans.learn.pipeline_status.stage.${stage}` : null;
}
