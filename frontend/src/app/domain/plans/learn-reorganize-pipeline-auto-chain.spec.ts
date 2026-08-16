import { describe, expect, it, beforeEach } from 'vitest';
import {
  clearLearnOrchestrationProgressCache,
  hydrateLearnOrchestrationProgress,
  readLearnOrchestrationCurrentPhase,
  readLearnOrchestrationPipelineActive
} from './learn-master-update-orchestration';
import {
  buildLearnReorganizePipelineStartNavigation,
  clearLearnReorganizePipelineAutoChain,
  readLearnReorganizePipelineAutoChain,
  setLearnReorganizePipelineError,
  storeLearnReorganizePipelineAutoChain,
  storeLearnReorganizePipelineAutoChainSkipPlacement,
  updateLearnReorganizePipelinePhase
} from './learn-reorganize-pipeline-auto-chain';

describe('learn-reorganize-pipeline-auto-chain', () => {
  beforeEach(() => {
    clearLearnOrchestrationProgressCache();
  });

  it('stores and reads auto-chain flag per plan via orchestration progress', () => {
    expect(readLearnReorganizePipelineAutoChain(7)).toBe(false);
    storeLearnReorganizePipelineAutoChain(7);
    expect(readLearnReorganizePipelineAutoChain(7)).toBe(true);
    expect(readLearnOrchestrationPipelineActive(7)).toBe(true);
    expect(readLearnReorganizePipelineAutoChain(8)).toBe(false);
    clearLearnReorganizePipelineAutoChain(7);
    expect(readLearnReorganizePipelineAutoChain(7)).toBe(false);
  });

  it('persists pipeline phase and error in orchestration progress', () => {
    storeLearnReorganizePipelineAutoChain(7);
    updateLearnReorganizePipelinePhase(7, 'optimizing');
    setLearnReorganizePipelineError(7, 'timeout');
    hydrateLearnOrchestrationProgress(7, {
      pipeline_active: true,
      current_phase: 'failed',
      last_error: 'timeout'
    });
    expect(readLearnReorganizePipelineAutoChain(7)).toBe(true);
  });

  it('builds adjust navigation for pipeline start', () => {
    expect(buildLearnReorganizePipelineStartNavigation(7)).toEqual({
      commands: ['/plans', 7],
      queryParams: { learningOrchestration: 'adjust' }
    });
  });

  it('stores skip-placement auto-chain at optimizing phase', () => {
    storeLearnReorganizePipelineAutoChainSkipPlacement(7);
    expect(readLearnReorganizePipelineAutoChain(7)).toBe(true);
    expect(readLearnOrchestrationCurrentPhase(7)).toBe('optimizing');
  });
});
