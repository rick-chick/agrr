import { describe, expect, it, beforeEach } from 'vitest';
import {
  buildLearnReorganizePipelineResumeNavigation,
  buildLearnReorganizePipelineStartNavigation,
  clearLearnReorganizePipelineAutoChain,
  readLearnReorganizePipelineAutoChain,
  readLearnReorganizePipelineFailure,
  reportLearnReorganizePipelineFailure,
  retryLearnReorganizePipeline,
  storeLearnReorganizePipelineAutoChain
} from './learn-reorganize-pipeline-auto-chain';
import { clearLearnOrchestrationProgressCache } from './learn-master-update-orchestration';

describe('learn-reorganize-pipeline-auto-chain', () => {
  beforeEach(() => {
    clearLearnOrchestrationProgressCache();
  });

  it('stores and reads auto-chain flag per plan via orchestration progress', () => {
    expect(readLearnReorganizePipelineAutoChain(7)).toBe(false);
    storeLearnReorganizePipelineAutoChain(7);
    expect(readLearnReorganizePipelineAutoChain(7)).toBe(true);
    expect(readLearnReorganizePipelineAutoChain(8)).toBe(false);
    clearLearnReorganizePipelineAutoChain(7);
    expect(readLearnReorganizePipelineAutoChain(7)).toBe(false);
  });

  it('builds adjust navigation for pipeline start', () => {
    expect(buildLearnReorganizePipelineStartNavigation(7)).toEqual({
      commands: ['/plans', 7],
      queryParams: { learningOrchestration: 'adjust' }
    });
  });

  it('builds resume navigation from persisted pipeline phase', () => {
    storeLearnReorganizePipelineAutoChain(7);
    expect(buildLearnReorganizePipelineResumeNavigation(7)).toEqual({
      commands: ['/plans', 7],
      queryParams: { learningOrchestration: 'adjust' }
    });
  });

  it('records pipeline failure and supports retry navigation', () => {
    reportLearnReorganizePipelineFailure(7, 'optimizing', 'Optimization failed');
    expect(readLearnReorganizePipelineAutoChain(7)).toBe(false);
    expect(readLearnReorganizePipelineFailure(7)).toEqual({
      failedPhase: 'optimizing',
      errorMessage: 'Optimization failed'
    });
    expect(retryLearnReorganizePipeline(7)).toEqual({
      commands: ['/plans', 7, 'optimizing']
    });
    expect(readLearnReorganizePipelineFailure(7)).toBeNull();
    expect(readLearnReorganizePipelineAutoChain(7)).toBe(true);
  });
});
