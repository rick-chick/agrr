import { describe, expect, it, vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { RegenerateTaskScheduleUseCase } from './regenerate-task-schedule.usecase';
import { PlanGateway } from './plan-gateway';
import { RegenerateTaskScheduleOutputPort } from './regenerate-task-schedule.output-port';
import { PollTaskScheduleSyncUseCase } from './poll-task-schedule-sync.usecase';

describe('RegenerateTaskScheduleUseCase', () => {
  it('calls gateway regenerate and notifies output port on success', () => {
    const response = { success: true, task_schedule_sync_state: 'ready' };
    const gateway = {
      regenerateTaskSchedule: vi.fn().mockReturnValue(of(response))
    } as unknown as PlanGateway;
    const outputPort: RegenerateTaskScheduleOutputPort = {
      onRegenerateStarted: vi.fn(),
      onRegenerateSuccess: vi.fn(),
      onRegenerateError: vi.fn()
    };
    const pollUseCase = { execute: vi.fn() } as unknown as PollTaskScheduleSyncUseCase;
    const useCase = new RegenerateTaskScheduleUseCase(outputPort, gateway, pollUseCase);

    useCase.execute({ planId: 7 });

    expect(outputPort.onRegenerateStarted).toHaveBeenCalled();
    expect(gateway.regenerateTaskSchedule).toHaveBeenCalledWith(7);
    expect(outputPort.onRegenerateSuccess).toHaveBeenCalledWith(response);
    expect(outputPort.onRegenerateError).not.toHaveBeenCalled();
    expect(pollUseCase.execute).not.toHaveBeenCalled();
  });

  it('starts bounded poll when POST returns generating', () => {
    const response = { success: true, task_schedule_sync_state: 'generating' };
    const gateway = {
      regenerateTaskSchedule: vi.fn().mockReturnValue(of(response))
    } as unknown as PlanGateway;
    const outputPort: RegenerateTaskScheduleOutputPort = {
      onRegenerateStarted: vi.fn(),
      onRegenerateSuccess: vi.fn(),
      onRegenerateError: vi.fn()
    };
    const pollUseCase = { execute: vi.fn() } as unknown as PollTaskScheduleSyncUseCase;
    const useCase = new RegenerateTaskScheduleUseCase(outputPort, gateway, pollUseCase);

    useCase.execute({ planId: 7 });

    expect(pollUseCase.execute).toHaveBeenCalledWith({ planId: 7 });
  });

  it('notifies output port on error', () => {
    const gateway = {
      regenerateTaskSchedule: vi.fn().mockReturnValue(throwError(() => ({ status: 500 })))
    } as unknown as PlanGateway;
    const outputPort: RegenerateTaskScheduleOutputPort = {
      onRegenerateStarted: vi.fn(),
      onRegenerateSuccess: vi.fn(),
      onRegenerateError: vi.fn()
    };
    const pollUseCase = { execute: vi.fn() } as unknown as PollTaskScheduleSyncUseCase;
    const useCase = new RegenerateTaskScheduleUseCase(outputPort, gateway, pollUseCase);

    useCase.execute({ planId: 7 });

    expect(outputPort.onRegenerateStarted).toHaveBeenCalled();
    expect(outputPort.onRegenerateError).toHaveBeenCalled();
    expect(outputPort.onRegenerateSuccess).not.toHaveBeenCalled();
  });
});
