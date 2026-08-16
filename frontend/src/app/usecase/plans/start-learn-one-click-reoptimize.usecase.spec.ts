import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  clearLearnOrchestrationProgressCache,
  hasLearnReorganizePipelineFailure,
  readLearnOrchestrationCurrentPhase
} from '../../domain/plans/learn-master-update-orchestration';
import { clearLearnReorganizePipelineAutoChain } from '../../domain/plans/learn-reorganize-pipeline-auto-chain';
import { ganttMutationCommandFailure, ganttMutationCommandSuccess } from '../../domain/plans/gantt-plan-mutation';
import { StartLearnOneClickReoptimizeUseCase } from './start-learn-one-click-reoptimize.usecase';
import type { GanttPlanGateway } from './gantt-plan-gateway';

describe('StartLearnOneClickReoptimizeUseCase', () => {
  let gateway: GanttPlanGateway;
  let useCase: StartLearnOneClickReoptimizeUseCase;

  beforeEach(() => {
    clearLearnOrchestrationProgressCache();
    clearLearnReorganizePipelineAutoChain();

    gateway = {
      loadPlanData: vi.fn(() =>
        of({
          success: true,
          data: {
            id: 7,
            plan_year: 2026,
            plan_name: 'Plan',
            status: 'active',
            total_area: 1,
            planning_start_date: '2026-01-01',
            planning_end_date: '2026-12-31',
            fields: [],
            crops: [],
            cultivations: [
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
            ]
          },
          total_profit: 0,
          total_revenue: 0,
          total_cost: 0
        })
      ),
      adjustPlanMoves: vi.fn(() => of(ganttMutationCommandSuccess())),
      adjustCultivationMove: vi.fn(),
      addCrop: vi.fn(),
      removeCultivation: vi.fn(),
      addField: vi.fn(),
      removeField: vi.fn(),
      syncLandingDemoPlan: vi.fn()
    } as unknown as GanttPlanGateway;

    useCase = new StartLearnOneClickReoptimizeUseCase(gateway);
  });

  it('posts current-placement adjust moves and starts optimizing-phase pipeline', () => {
    const onSuccess = vi.fn();
    useCase.execute({ planId: 7, onSuccess });

    expect(gateway.adjustPlanMoves).toHaveBeenCalledWith({
      planType: 'private',
      planId: 7,
      moves: [
        {
          allocation_id: 10,
          action: 'move',
          to_field_id: 3,
          to_start_date: '2026-04-01'
        }
      ]
    });
    expect(readLearnOrchestrationCurrentPhase(7)).toBe('optimizing');
    expect(onSuccess).toHaveBeenCalled();
  });

  it('records pipeline failure when adjust fails', () => {
    vi.mocked(gateway.adjustPlanMoves).mockReturnValue(
      of(ganttMutationCommandFailure('bad request'))
    );
    const onError = vi.fn();
    useCase.execute({ planId: 7, onError });

    expect(hasLearnReorganizePipelineFailure(7)).toBe(true);
    expect(onError).toHaveBeenCalledWith('bad request');
  });

  it('reports error when plan has no cultivations', () => {
    vi.mocked(gateway.loadPlanData).mockReturnValue(
      of({
        success: true,
        data: {
          id: 7,
          plan_year: 2026,
          plan_name: 'Plan',
          status: 'active',
          total_area: 0,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [],
          crops: [],
          cultivations: []
        },
        total_profit: 0,
        total_revenue: 0,
        total_cost: 0
      })
    );
    const onError = vi.fn();
    useCase.execute({ planId: 7, onError });

    expect(onError).toHaveBeenCalledWith('plans.learn.one_click_reoptimize.error.no_cultivations');
    expect(gateway.adjustPlanMoves).not.toHaveBeenCalled();
  });

  it('reports load failure', () => {
    vi.mocked(gateway.loadPlanData).mockReturnValue(throwError(() => new Error('network')));
    const onError = vi.fn();
    useCase.execute({ planId: 7, onError });

    expect(onError).toHaveBeenCalled();
  });
});
