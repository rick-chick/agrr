import { of, throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { RegenerateTaskScheduleUseCase } from './regenerate-task-schedule.usecase';
import { PlanGateway } from './plan-gateway';
import { RegenerateTaskScheduleOutputPort } from './regenerate-task-schedule.output-port';

describe('RegenerateTaskScheduleUseCase', () => {
  it('calls gateway regenerate and notifies output port on success', () => {
    const gateway = {
      regenerateTaskSchedule: vi.fn().mockReturnValue(of(undefined))
    } as unknown as PlanGateway;
    const outputPort: RegenerateTaskScheduleOutputPort = {
      onRegenerateStarted: vi.fn(),
      onRegenerateSuccess: vi.fn(),
      onRegenerateError: vi.fn()
    };
    const useCase = new RegenerateTaskScheduleUseCase(outputPort, gateway);

    useCase.execute({ planId: 7 });

    expect(outputPort.onRegenerateStarted).toHaveBeenCalled();
    expect(gateway.regenerateTaskSchedule).toHaveBeenCalledWith(7);
    expect(outputPort.onRegenerateSuccess).toHaveBeenCalled();
    expect(outputPort.onRegenerateError).not.toHaveBeenCalled();
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
    const useCase = new RegenerateTaskScheduleUseCase(outputPort, gateway);

    useCase.execute({ planId: 7 });

    expect(outputPort.onRegenerateStarted).toHaveBeenCalled();
    expect(outputPort.onRegenerateError).toHaveBeenCalled();
    expect(outputPort.onRegenerateSuccess).not.toHaveBeenCalled();
  });
});
