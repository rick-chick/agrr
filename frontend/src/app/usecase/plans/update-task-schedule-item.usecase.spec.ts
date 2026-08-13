import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { UpdateTaskScheduleItemUseCase } from './update-task-schedule-item.usecase';
import { PlanGateway } from './plan-gateway';
import { UpdateTaskScheduleItemOutputPort } from './update-task-schedule-item.output-port';

describe('UpdateTaskScheduleItemUseCase', () => {
  const updateFn = vi.fn(() =>
    of({
      item: {
        id: 1,
        name: 'Weeding',
        scheduled_date: '2026-07-15',
        status: 'rescheduled'
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
      createTaskScheduleItem: () => of({} as never),
      updateTaskScheduleItem: updateFn,
      deletePlan: () => of({} as never)
    }) as PlanGateway;

  it('patches scheduled_date via gateway', () => {
    updateFn.mockClear();
    const onSuccess = vi.fn();
    const outputPort: UpdateTaskScheduleItemOutputPort = {
      onSuccess,
      onError: () => {}
    };
    const useCase = new UpdateTaskScheduleItemUseCase(outputPort, gateway());
    useCase.execute({ planId: 5, itemId: 9, scheduledDate: '2026-07-15', onSuccess });

    expect(updateFn).toHaveBeenCalledWith(5, 9, { scheduled_date: '2026-07-15' });
    expect(onSuccess).toHaveBeenCalled();
  });

  it('calls onError when gateway fails', () => {
    const failingGateway = {
      ...gateway(),
      updateTaskScheduleItem: () => throwError(() => new Error('fail'))
    } as PlanGateway;
    const onError = vi.fn();
    const outputPort: UpdateTaskScheduleItemOutputPort = {
      onSuccess: () => {},
      onError
    };
    const useCase = new UpdateTaskScheduleItemUseCase(outputPort, failingGateway);
    useCase.execute({ planId: 5, itemId: 9, scheduledDate: '2026-07-15' });

    expect(onError).toHaveBeenCalled();
  });
});
