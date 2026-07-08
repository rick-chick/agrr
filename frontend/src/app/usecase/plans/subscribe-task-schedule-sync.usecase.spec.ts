import { describe, expect, it, vi } from 'vitest';
import { SubscribeTaskScheduleSyncUseCase } from './subscribe-task-schedule-sync.usecase';
import { PlanOptimizationGateway } from './plan-optimization-gateway';
import { SubscribeTaskScheduleSyncOutputPort } from './subscribe-task-schedule-sync.output-port';
import { TaskScheduleSyncMessageDto } from './subscribe-task-schedule-sync.dtos';

describe('SubscribeTaskScheduleSyncUseCase', () => {
  it('subscribes via gateway and forwards DTO to output port', () => {
    let received: ((message: TaskScheduleSyncMessageDto) => void) | undefined;
    const channel = { unsubscribe: vi.fn() };
    const gateway = {
      subscribeTaskScheduleSync: vi.fn(
        (_planId: number, callbacks: { received: (message: TaskScheduleSyncMessageDto) => void }) => {
          received = callbacks.received;
          return channel;
        }
      )
    } as unknown as PlanOptimizationGateway;
    const outputPort: SubscribeTaskScheduleSyncOutputPort = {
      onTaskScheduleSync: vi.fn()
    };
    const useCase = new SubscribeTaskScheduleSyncUseCase(outputPort, gateway);
    const onSubscribed = vi.fn();

    useCase.execute({ planId: 7, onSubscribed });

    expect(gateway.subscribeTaskScheduleSync).toHaveBeenCalledWith(7, expect.any(Object));
    expect(onSubscribed).toHaveBeenCalledWith(channel);

    const dto: TaskScheduleSyncMessageDto = {
      syncState: 'ready',
      syncError: null,
      syncErrorCropId: null
    };
    received?.(dto);
    expect(outputPort.onTaskScheduleSync).toHaveBeenCalledWith(dto);
  });
});
