import { describe, it, expect, beforeEach, vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { ResolveEntryScheduleFarmUseCase } from './resolve-entry-schedule-farm.usecase';
import { ResolveEntryScheduleFarmOutputPort } from './resolve-entry-schedule-farm.output-port';
import { EntryScheduleGateway } from './entry-schedule-gateway';

describe('ResolveEntryScheduleFarmUseCase', () => {
  let outputPort: ResolveEntryScheduleFarmOutputPort;
  let gateway: EntryScheduleGateway;
  let useCase: ResolveEntryScheduleFarmUseCase;

  const farms = [
    { id: 1, name: 'Farm A', latitude: 35, longitude: 139, region: 'jp' },
    { id: 2, name: 'Farm B', latitude: 34, longitude: 135, region: 'jp' }
  ];

  beforeEach(() => {
    outputPort = {
      presentFarm: vi.fn(),
      onInvalidFarm: vi.fn()
    };
    gateway = {
      getEntryScheduleFarms: vi.fn(),
      getEntryScheduleCrops: vi.fn(),
      getEntryScheduleCrop: vi.fn()
    };
    useCase = new ResolveEntryScheduleFarmUseCase(outputPort, gateway);
  });

  it('calls presentFarm when farm id matches', async () => {
    vi.mocked(gateway.getEntryScheduleFarms).mockReturnValue(of(farms));

    useCase.execute({ region: 'jp', farmId: 1 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.presentFarm).toHaveBeenCalledWith({ farm: farms[0] });
    expect(outputPort.onInvalidFarm).not.toHaveBeenCalled();
  });

  it('calls onInvalidFarm when farm id is not found', async () => {
    vi.mocked(gateway.getEntryScheduleFarms).mockReturnValue(of(farms));

    useCase.execute({ region: 'jp', farmId: 999 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onInvalidFarm).toHaveBeenCalled();
    expect(outputPort.presentFarm).not.toHaveBeenCalled();
  });

  it('calls onInvalidFarm when gateway fails', async () => {
    vi.mocked(gateway.getEntryScheduleFarms).mockReturnValue(
      throwError(() => new Error('Network error'))
    );

    useCase.execute({ region: 'jp', farmId: 1 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onInvalidFarm).toHaveBeenCalled();
    expect(outputPort.presentFarm).not.toHaveBeenCalled();
  });
});
