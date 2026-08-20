import { beforeEach, describe, expect, it } from 'vitest';
import {
  clearLearnOrchestrationProgressCache,
  readLearnOrchestrationCurrentPhase
} from './learn-master-update-orchestration';
import {
  clearLearnReorganizePipelineAutoChain,
  readLearnReorganizePipelineAutoChain,
  setLearnReorganizePipelineError,
  storeLearnReorganizePipelineAutoChain,
  storeLearnReorganizePipelineAutoChainSkipPlacement
} from './learn-reorganize-pipeline-auto-chain';
import { markStageGddProposalAppliedPending, clearLearnProposalApplicationProgressCache } from './learn-proposal-application-progress';
import {
  buildCurrentPlacementAdjustMoves,
  buildLearnReorganizeSkipPlacementOptimizingNavigation,
  shouldShowLearnOneClickReoptimizeCta
} from './learn-reorganize-skip-placement-pipeline';

describe('learn-reorganize-skip-placement-pipeline', () => {
  beforeEach(() => {
    clearLearnOrchestrationProgressCache();
    clearLearnReorganizePipelineAutoChain();
    clearLearnProposalApplicationProgressCache();
  });

  describe('buildCurrentPlacementAdjustMoves', () => {
    it('builds adjust moves from current cultivation placements', () => {
      const moves = buildCurrentPlacementAdjustMoves([
        {
          id: 10,
          field_id: 3,
          field_name: 'North',
          crop_id: 1,
          crop_name: 'Tomato',
          area: 1,
          start_date: '2026-04-01',
          completion_date: '2026-08-01',
          cultivation_days: 120,
          estimated_cost: 0,
          revenue: 0,
          profit: 0,
          status: 'active'
        }
      ]);

      expect(moves).toEqual([
        {
          allocation_id: 10,
          action: 'move',
          to_field_id: 3,
          to_start_date: '2026-04-01'
        }
      ]);
    });
  });

  describe('shouldShowLearnOneClickReoptimizeCta', () => {
    it('is true when master update flow is active and pipeline is idle', () => {
      markStageGddProposalAppliedPending(7, { cropId: 1, stageId: 2 });
      expect(shouldShowLearnOneClickReoptimizeCta(7)).toBe(true);
    });

    it('is false when pipeline is active', () => {
      markStageGddProposalAppliedPending(7, { cropId: 1, stageId: 2 });
      storeLearnReorganizePipelineAutoChain(7);
      expect(shouldShowLearnOneClickReoptimizeCta(7)).toBe(false);
    });

    it('is false when server reoptimize enqueue failed', () => {
      markStageGddProposalAppliedPending(7, { cropId: 1, stageId: 2 });
      storeLearnReorganizePipelineAutoChainSkipPlacement(7);
      setLearnReorganizePipelineError(7, 'plans.learn.one_click_reoptimize.error.adjust_failed');
      expect(shouldShowLearnOneClickReoptimizeCta(7)).toBe(false);
    });

    it('is false when master update flow is inactive', () => {
      expect(shouldShowLearnOneClickReoptimizeCta(7)).toBe(false);
    });
  });

  describe('buildLearnReorganizeSkipPlacementOptimizingNavigation', () => {
    it('targets optimizing route', () => {
      expect(buildLearnReorganizeSkipPlacementOptimizingNavigation(7)).toEqual({
        commands: ['/plans', 7, 'optimizing']
      });
    });
  });

  describe('storeLearnReorganizePipelineAutoChainSkipPlacement', () => {
    it('starts auto-chain at optimizing phase', () => {
      storeLearnReorganizePipelineAutoChainSkipPlacement(7);
      expect(readLearnReorganizePipelineAutoChain(7)).toBe(true);
      expect(readLearnOrchestrationCurrentPhase(7)).toBe('optimizing');
    });
  });
});
