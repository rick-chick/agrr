import { describe, expect, it, beforeEach, vi } from 'vitest';
import {
  areAllLearnOrchestrationStepsComplete,
  buildLearnOrchestrationResumeNavigation,
  buildLearningOrchestrationNavigation,
  buildPlanDetailAdjustNavigation,
  buildPlanTaskScheduleOrchestrationNavigation,
  clearLearnOrchestrationProgressCache,
  clearLearnOrchestrationReturnToLearn,
  findFirstIncompleteOrchestrationStep,
  hasActiveLearnMasterUpdateFlow,
  hasPendingMasterUpdateConfirmation,
  hydrateLearnOrchestrationProgress,
  isTaskScheduleOrchestrationComplete,
  markLearnOrchestrationStepComplete,
  parseLearningOrchestration,
  readLearnOrchestrationReturnToLearn,
  readLearnOrchestrationStepComplete,
  registerLearnOrchestrationProgressPatchHandler,
  storeLearnOrchestrationReturnToLearn
} from './learn-master-update-orchestration';
import {
  clearLearnProposalApplicationProgressCache,
  markLearnProposalConfirmed,
  markStageGddProposalAppliedPending,
  readLearnProposalApplicationProgress,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from './learn-proposal-application-progress';

describe('learn-master-update-orchestration', () => {
  beforeEach(() => {
    clearLearnOrchestrationProgressCache();
    clearLearnProposalApplicationProgressCache();
  });

  describe('parseLearningOrchestration', () => {
    it('parses adjust, regenerate, and sync_verify modes', () => {
      expect(parseLearningOrchestration('adjust')).toBe('adjust');
      expect(parseLearningOrchestration('regenerate')).toBe('regenerate');
      expect(parseLearningOrchestration('sync_verify')).toBe('sync_verify');
    });

    it('returns null for unknown or empty values', () => {
      expect(parseLearningOrchestration(null)).toBeNull();
      expect(parseLearningOrchestration('')).toBeNull();
      expect(parseLearningOrchestration('invalid')).toBeNull();
    });
  });

  describe('navigation helpers', () => {
    it('builds plan detail adjust navigation with learningOrchestration query param', () => {
      expect(buildPlanDetailAdjustNavigation(7)).toEqual({
        commands: ['/plans', 7],
        queryParams: { learningOrchestration: 'adjust' }
      });
    });

    it('builds task schedule navigation for regenerate and sync_verify steps', () => {
      expect(buildPlanTaskScheduleOrchestrationNavigation(7, 'regenerate')).toEqual({
        commands: ['/plans', 7, 'task_schedule'],
        queryParams: { learningOrchestration: 'regenerate' }
      });
      expect(buildPlanTaskScheduleOrchestrationNavigation(7, 'sync_verify')).toEqual({
        commands: ['/plans', 7, 'task_schedule'],
        queryParams: { learningOrchestration: 'sync_verify' }
      });
    });

    it('builds generic learning orchestration navigation', () => {
      expect(buildLearningOrchestrationNavigation(3, 'adjust')).toEqual({
        commands: ['/plans', 3],
        queryParams: { learningOrchestration: 'adjust' }
      });
    });

    it('builds resume navigation for the first incomplete step', () => {
      hydrateLearnOrchestrationProgress(3, { placement: true });
      expect(buildLearnOrchestrationResumeNavigation(3)).toEqual({
        commands: ['/plans', 3, 'task_schedule'],
        queryParams: { learningOrchestration: 'regenerate' }
      });
      expect(findFirstIncompleteOrchestrationStep(3)).toBe('regenerate');
    });

    it('builds resume navigation from persisted pipeline phase after reload', () => {
      hydrateLearnOrchestrationProgress(3, {
        pipeline_active: true,
        current_phase: 'optimizing'
      });
      expect(buildLearnOrchestrationResumeNavigation(3)).toEqual({
        commands: ['/plans', 3, 'optimizing'],
        queryParams: { learningOrchestration: 'adjust' }
      });
    });
  });

  describe('optimizing return context', () => {
    it('stores and reads return-to-learn flag per plan', () => {
      expect(readLearnOrchestrationReturnToLearn(5)).toBe(false);

      storeLearnOrchestrationReturnToLearn(5);
      expect(readLearnOrchestrationReturnToLearn(5)).toBe(true);

      clearLearnOrchestrationReturnToLearn(5);
      expect(readLearnOrchestrationReturnToLearn(5)).toBe(false);
    });
  });

  describe('task schedule orchestration completion', () => {
    it('is complete when sync is ready and not regenerating', () => {
      expect(isTaskScheduleOrchestrationComplete('regenerate', 'ready', false)).toBe(true);
      expect(isTaskScheduleOrchestrationComplete('sync_verify', 'ready', false)).toBe(true);
    });

    it('is not complete while regenerating or sync is not ready', () => {
      expect(isTaskScheduleOrchestrationComplete('regenerate', 'ready', true)).toBe(false);
      expect(isTaskScheduleOrchestrationComplete('regenerate', 'generating', false)).toBe(false);
      expect(isTaskScheduleOrchestrationComplete('sync_verify', 'failed', false)).toBe(false);
    });
  });

  describe('orchestration step progress', () => {
    it('stores and reads step completion per plan from hydrated cache', () => {
      expect(readLearnOrchestrationStepComplete(5, 'regenerate')).toBe(false);

      markLearnOrchestrationStepComplete(5, 'regenerate');
      expect(readLearnOrchestrationStepComplete(5, 'regenerate')).toBe(true);
      expect(readLearnOrchestrationStepComplete(5, 'sync_verify')).toBe(false);

      markLearnOrchestrationStepComplete(5, 'sync_verify');
      expect(readLearnOrchestrationStepComplete(5, 'sync_verify')).toBe(true);
    });

    it('hydrates orchestration progress from server snapshot', () => {
      hydrateLearnOrchestrationProgress(5, {
        placement: true,
        regenerate: true,
        sync_verify: false,
        return_to_learn: false
      });
      expect(readLearnOrchestrationStepComplete(5, 'placement')).toBe(true);
      expect(readLearnOrchestrationStepComplete(5, 'regenerate')).toBe(true);
      expect(readLearnOrchestrationStepComplete(5, 'sync_verify')).toBe(false);
    });
  });

  describe('hasPendingMasterUpdateConfirmation', () => {
    it('is true when any proposal is applied_pending_confirmation', () => {
      markStageGddProposalAppliedPending(9, { cropId: 1, stageId: 2 });
      expect(hasPendingMasterUpdateConfirmation(9)).toBe(true);
      expect(readLearnProposalApplicationProgress(9)['stage_gdd:1:2']).toBe(
        'applied_pending_confirmation'
      );
    });

    it('is false when no pending confirmations exist', () => {
      expect(hasPendingMasterUpdateConfirmation(9)).toBe(false);
    });
  });

  describe('hasActiveLearnMasterUpdateFlow', () => {
    it('is true when any proposal is confirmed', () => {
      markLearnProposalConfirmed(9, stageGddProposalProgressKey(1, 2));
      expect(hasActiveLearnMasterUpdateFlow(9)).toBe(true);
    });

    it('is false when all proposals are done', () => {
      markLearnProposalConfirmed(9, stageGddProposalProgressKey(1, 2));
      markLearnOrchestrationStepComplete(9, 'placement');
      markLearnOrchestrationStepComplete(9, 'regenerate');
      markLearnOrchestrationStepComplete(9, 'sync_verify');
      expect(hasActiveLearnMasterUpdateFlow(9)).toBe(false);
      expect(resolveLearnProposalApplicationStatus(9, stageGddProposalProgressKey(1, 2))).toBe(
        'done'
      );
    });
  });

  describe('areAllLearnOrchestrationStepsComplete', () => {
    it('is true only when placement, regenerate, and sync_verify are complete', () => {
      expect(areAllLearnOrchestrationStepsComplete(5)).toBe(false);
      markLearnOrchestrationStepComplete(5, 'placement');
      markLearnOrchestrationStepComplete(5, 'regenerate');
      expect(areAllLearnOrchestrationStepsComplete(5)).toBe(false);
      markLearnOrchestrationStepComplete(5, 'sync_verify');
      expect(areAllLearnOrchestrationStepsComplete(5)).toBe(true);
    });

    it('marks confirmed proposals done when final orchestration step completes', () => {
      const key = stageGddProposalProgressKey(1, 2);
      markStageGddProposalAppliedPending(5, { cropId: 1, stageId: 2 });
      markLearnProposalConfirmed(5, key);

      markLearnOrchestrationStepComplete(5, 'placement');
      markLearnOrchestrationStepComplete(5, 'regenerate');
      expect(resolveLearnProposalApplicationStatus(5, key)).toBe('confirmed');

      markLearnOrchestrationStepComplete(5, 'sync_verify');
      expect(resolveLearnProposalApplicationStatus(5, key)).toBe('done');
    });
  });

  describe('orchestration patch handler registration', () => {
    it('invokes patch handler when marking orchestration step complete', () => {
      const handler = vi.fn();
      registerLearnOrchestrationProgressPatchHandler(handler);

      markLearnOrchestrationStepComplete(5, 'regenerate');

      expect(handler).toHaveBeenCalledWith(5, { regenerate: true });
    });

    it('does not invoke patch handler when hydrating local orchestration cache', () => {
      const handler = vi.fn();
      registerLearnOrchestrationProgressPatchHandler(handler);

      hydrateLearnOrchestrationProgress(7, {
        pipeline_active: true,
        current_phase: 'optimizing',
        last_error: null
      });

      expect(handler).not.toHaveBeenCalled();
    });
  });
});
