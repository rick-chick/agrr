import { of, throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { LoadPlanTaskScheduleUseCase } from './load-plan-task-schedule.usecase';
import { PlanGateway } from './plan-gateway';
import { LoadPlanTaskScheduleOutputPort } from './load-plan-task-schedule.output-port';
import { PlanTaskScheduleDataDto } from './load-plan-task-schedule.dtos';

describe('LoadPlanTaskScheduleUseCase', () => {
  const schedule = {
    plan: {} as TaskScheduleResponse['plan'],
    week: {} as TaskScheduleResponse['week'],
    milestones: [],
    fields: [],
    labels: {},
    minimap: { start_date: '', end_date: '', weeks: [] }
  } satisfies TaskScheduleResponse;

  it('fetches task schedule by planId only and presents result', () => {
    const getTaskSchedule = vi.fn().mockReturnValue(of(schedule));
    const gateway = { getTaskSchedule } as unknown as PlanGateway;
    let received: PlanTaskScheduleDataDto | null = null;
    const outputPort: LoadPlanTaskScheduleOutputPort = {
      present: (dto) => {
        received = dto;
      },
      onError: vi.fn()
    };
    const useCase = new LoadPlanTaskScheduleUseCase(outputPort, gateway);

    useCase.execute({ planId: 7 });

    expect(getTaskSchedule).toHaveBeenCalledWith(7);
    expect(received?.schedule).toEqual(schedule);
    expect(outputPort.onError).not.toHaveBeenCalled();
  });

  it('notifies output port on gateway error', () => {
    const gateway = {
      getTaskSchedule: vi.fn().mockReturnValue(throwError(() => ({ status: 500 })))
    } as unknown as PlanGateway;
    const outputPort: LoadPlanTaskScheduleOutputPort = {
      present: vi.fn(),
      onError: vi.fn()
    };
    const useCase = new LoadPlanTaskScheduleUseCase(outputPort, gateway);

    useCase.execute({ planId: 7 });

    expect(gateway.getTaskSchedule).toHaveBeenCalledWith(7);
    expect(outputPort.onError).toHaveBeenCalled();
    expect(outputPort.present).not.toHaveBeenCalled();
  });
});
