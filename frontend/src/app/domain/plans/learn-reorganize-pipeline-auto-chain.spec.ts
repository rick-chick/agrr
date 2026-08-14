import { describe, expect, it, beforeEach } from 'vitest';
import {
  buildLearnReorganizePipelineStartNavigation,
  clearLearnReorganizePipelineAutoChain,
  readLearnReorganizePipelineAutoChain,
  storeLearnReorganizePipelineAutoChain
} from './learn-reorganize-pipeline-auto-chain';

describe('learn-reorganize-pipeline-auto-chain', () => {
  beforeEach(() => {
    clearLearnReorganizePipelineAutoChain();
  });

  it('stores and reads auto-chain flag per plan', () => {
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
});
