import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { CreateTaskScheduleItemUseCase } from './create-task-schedule-item.usecase';
import { PlanGateway } from './plan-gateway';
import { CreateTaskScheduleItemOutputPort } from './create-task-schedule-item.output-port';

describe('CreateTaskScheduleItemUseCase', () => {
  const createFn = vi.fn(() =>
    of({
      item: {
        id: 42,
        name: 'Manual task',
        scheduled_date: '2026-07-10',
        status: 'planned'
      }
    })
  );

  const gateway = (): PlanGateway =>
    ({
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({} as never),
      getPlanVsActualSummary: () => of({} as never),
      getVarianceLearning: () => of({} as never),
      importVarianceLearning: () => of({} as never),
      patchVarianceLearningProposalProgress: () => of({} as never),
      regenerateTaskSchedule: () => of({} as never),
      createTaskScheduleItem: createFn,
      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as never)
    }) as PlanGateway;

  it('posts create payload via gateway', () => {
    createFn.mockClear();
    const onSuccess = vi.fn();
    const outputPort: CreateTaskScheduleItemOutputPort = {
      onSuccess,
      onError: () => {}
    };
    const useCase = new CreateTaskScheduleItemUseCase(outputPort, gateway());
    useCase.execute({
      planId: 5,
      fieldCultivationId: 11,
      name: 'Manual task',
      scheduledDate: '2026-07-10'
    });

    expect(createFn).toHaveBeenCalledWith(5, {
      field_cultivation_id: 11,
      name: 'Manual task',
      scheduled_date: '2026-07-10',
      agricultural_task_id: undefined
    });
    expect(onSuccess).toHaveBeenCalled();
  });

  it('calls onError when gateway fails', () => {
    const failingGateway = {
      ...gateway(),
      createTaskScheduleItem: () => throwError(() => new Error('fail'))
    } as PlanGateway;
    const onError = vi.fn();
    const onErrorCallback = vi.fn();
    const outputPort: CreateTaskScheduleItemOutputPort = {
      onSuccess: () => {},
      onError
    };
    const useCase = new CreateTaskScheduleItemUseCase(outputPort, failingGateway);
    useCase.execute({
      planId: 5,
      fieldCultivationId: 11,
      name: 'Manual task',
      scheduledDate: '2026-07-10',
      onError: onErrorCallback
    });

    expect(onError).toHaveBeenCalled();
    expect(onErrorCallback).toHaveBeenCalled();
  });
});
