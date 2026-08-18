import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  clearLearnOrchestrationProgressCache,
  hasLearnReorganizePipelineFailure,
  readLearnOrchestrationCurrentPhase
} from '../../domain/plans/learn-master-update-orchestration';
import { clearLearnReorganizePipelineAutoChain } from '../../domain/plans/learn-reorganize-pipeline-auto-chain';
import type { PlanGateway } from './plan-gateway';
import {
  StartLearnVarianceLearningReoptimizeUseCase
} from './start-learn-variance-learning-reoptimize.usecase';

describe('StartLearnVarianceLearningReoptimizeUseCase', () => {
  let gateway: PlanGateway;
  let useCase: StartLearnVarianceLearningReoptimizeUseCase;

  beforeEach(() => {
    clearLearnOrchestrationProgressCache();
    clearLearnReorganizePipelineAutoChain();

    gateway = {
      reoptimizeVarianceLearning: vi.fn(() =>
        of({ success: true, plan_id: 7, optimization_enqueued: true })
      )
    } as unknown as PlanGateway;

    useCase = new StartLearnVarianceLearningReoptimizeUseCase(gateway);
  });

  it('posts variance_learning reoptimize and starts optimizing-phase pipeline', () => {
    const onSuccess = vi.fn();
    useCase.execute({ planId: 7, onSuccess });

    expect(gateway.reoptimizeVarianceLearning).toHaveBeenCalledWith(7);
    expect(readLearnOrchestrationCurrentPhase(7)).toBe('optimizing');
    expect(onSuccess).toHaveBeenCalled();
  });

  it('records pipeline failure when enqueue is not confirmed', () => {
    vi.mocked(gateway.reoptimizeVarianceLearning).mockReturnValue(
      of({ success: true, plan_id: 7, optimization_enqueued: false })
    );
    const onError = vi.fn();
    useCase.execute({ planId: 7, onError });

    expect(hasLearnReorganizePipelineFailure(7)).toBe(true);
    expect(onError).toHaveBeenCalledWith('plans.learn.one_click_reoptimize.error.adjust_failed');
  });

  it('records pipeline failure when API errors', () => {
    vi.mocked(gateway.reoptimizeVarianceLearning).mockReturnValue(
      throwError(() => new Error('network'))
    );
    const onError = vi.fn();
    useCase.execute({ planId: 7, onError });

    expect(hasLearnReorganizePipelineFailure(7)).toBe(true);
    expect(onError).toHaveBeenCalled();
  });
});
