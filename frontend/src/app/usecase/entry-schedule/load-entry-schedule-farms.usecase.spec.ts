import { describe, it, expect, beforeEach, vi } from 'vitest';
import { of, throwError, TimeoutError } from 'rxjs';
import { LoadEntryScheduleFarmsUseCase } from './load-entry-schedule-farms.usecase';
import { LoadEntryScheduleFarmsOutputPort } from './load-entry-schedule-farms.output-port';
import { EntryScheduleGateway } from './entry-schedule-gateway';

describe('LoadEntryScheduleFarmsUseCase', () => {
  let outputPort: LoadEntryScheduleFarmsOutputPort;
  let gateway: EntryScheduleGateway;
  let useCase: LoadEntryScheduleFarmsUseCase;

  beforeEach(() => {
    outputPort = {
      present: vi.fn(),
      onError: vi.fn()
    };
    gateway = {
      getEntryScheduleFarms: vi.fn(),
      getEntryScheduleCrops: vi.fn(),
      getEntryScheduleCrop: vi.fn()
    };
    useCase = new LoadEntryScheduleFarmsUseCase(outputPort, gateway);
  });

  it('calls present when getEntryScheduleFarms succeeds', async () => {
    const farms = [{ id: 1, name: 'Farm A', region: 'jp', latitude: 35, longitude: 139 }];

    vi.mocked(gateway.getEntryScheduleFarms).mockReturnValue(of(farms));

    useCase.execute({ region: 'jp' });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.present).toHaveBeenCalledWith({ farms });
    expect(outputPort.onError).not.toHaveBeenCalled();
  });

  it('calls onError with entrySchedule.error when getEntryScheduleFarms fails', async () => {
    vi.mocked(gateway.getEntryScheduleFarms).mockReturnValue(
      throwError(() => new Error('Network error'))
    );

    useCase.execute({ region: 'jp' });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({ message: 'entrySchedule.error' });
    expect(outputPort.present).not.toHaveBeenCalled();
  });

  it('calls onError with entrySchedule.timeout when request times out', async () => {
    vi.mocked(gateway.getEntryScheduleFarms).mockReturnValue(
      throwError(() => new TimeoutError())
    );

    useCase.execute({ region: 'jp' });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({ message: 'entrySchedule.timeout' });
    expect(outputPort.present).not.toHaveBeenCalled();
  });
});
