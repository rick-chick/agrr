import { describe, expect, it } from 'vitest';
import {
  resolveLearnReorganizePipelineStage,
  resolveLearnReorganizePipelineStageLabelKey
} from './resolve-learn-reorganize-pipeline-stage';

describe('resolve-learn-reorganize-pipeline-stage', () => {
  it('maps pipeline phases to adjust, optimizing, and task_schedule stages', () => {
    expect(resolveLearnReorganizePipelineStage('placement')).toBe('adjust');
    expect(resolveLearnReorganizePipelineStage('optimizing')).toBe('optimizing');
    expect(resolveLearnReorganizePipelineStage('regenerate')).toBe('task_schedule');
    expect(resolveLearnReorganizePipelineStage('sync_verify')).toBe('task_schedule');
  });

  it('returns null for idle, failed, and completed phases', () => {
    expect(resolveLearnReorganizePipelineStage('idle')).toBeNull();
    expect(resolveLearnReorganizePipelineStage('failed')).toBeNull();
    expect(resolveLearnReorganizePipelineStage('completed')).toBeNull();
  });

  it('builds i18n label keys for observable pipeline stages', () => {
    expect(resolveLearnReorganizePipelineStageLabelKey('placement')).toBe(
      'plans.learn.pipeline_status.stage.adjust'
    );
    expect(resolveLearnReorganizePipelineStageLabelKey('optimizing')).toBe(
      'plans.learn.pipeline_status.stage.optimizing'
    );
    expect(resolveLearnReorganizePipelineStageLabelKey('regenerate')).toBe(
      'plans.learn.pipeline_status.stage.task_schedule'
    );
    expect(resolveLearnReorganizePipelineStageLabelKey('failed')).toBeNull();
  });
});
