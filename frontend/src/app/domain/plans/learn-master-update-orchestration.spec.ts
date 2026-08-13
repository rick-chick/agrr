import { describe, expect, it, beforeEach } from 'vitest';
import {
  buildLearningOrchestrationNavigation,
  buildPlanDetailAdjustNavigation,
  buildPlanTaskScheduleOrchestrationNavigation,
  clearLearnOrchestrationReturnToLearn,
  hasPendingMasterUpdateConfirmation,
  isTaskScheduleOrchestrationComplete,
  learnOrchestrationReturnStorageKey,
  learnOrchestrationStepProgressStorageKey,
  markLearnOrchestrationStepComplete,
  parseLearningOrchestration,
  readLearnOrchestrationReturnToLearn,
  readLearnOrchestrationStepComplete,
  storeLearnOrchestrationReturnToLearn
} from './learn-master-update-orchestration';
import {
  markStageGddProposalAppliedPending,
  readLearnProposalApplicationProgress
} from './learn-proposal-application-progress';

describe('learn-master-update-orchestration', () => {
  beforeEach(() => {
    sessionStorage.clear();
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
  });

  describe('optimizing return context', () => {
    it('stores and reads return-to-learn flag per plan', () => {
      expect(learnOrchestrationReturnStorageKey(5)).toBe('agrr:learn-orchestration-return:5');
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
    it('stores and reads step completion per plan', () => {
      expect(learnOrchestrationStepProgressStorageKey(5)).toBe(
        'agrr:learn-orchestration-step-progress:5'
      );
      expect(readLearnOrchestrationStepComplete(5, 'regenerate')).toBe(false);

      markLearnOrchestrationStepComplete(5, 'regenerate');
      expect(readLearnOrchestrationStepComplete(5, 'regenerate')).toBe(true);
      expect(readLearnOrchestrationStepComplete(5, 'sync_verify')).toBe(false);

      markLearnOrchestrationStepComplete(5, 'sync_verify');
      expect(readLearnOrchestrationStepComplete(5, 'sync_verify')).toBe(true);
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
});
