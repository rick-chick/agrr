import { describe, expect, it, vi } from 'vitest';
import { SubscribePlanOptimizationUseCase } from './subscribe-plan-optimization.usecase';
import { PlanOptimizationGateway } from './plan-optimization-gateway';
import { SubscribePlanOptimizationOutputPort } from './subscribe-plan-optimization.output-port';

describe('SubscribePlanOptimizationUseCase', () => {
  function createHarness() {
    let disconnected: (() => void) | undefined;
    let rejected: (() => void) | undefined;
    const channel = { unsubscribe: vi.fn() };
    const gateway = {
      subscribe: vi.fn(
        (
          _planId: number,
          callbacks: { received: () => void; disconnected?: () => void; rejected?: () => void }
        ) => {
          disconnected = callbacks.disconnected;
          rejected = callbacks.rejected;
          return channel;
        }
      )
    } as unknown as PlanOptimizationGateway;
    const outputPort: SubscribePlanOptimizationOutputPort = {
      present: vi.fn(),
      presentConnectionLost: vi.fn()
    };
    const useCase = new SubscribePlanOptimizationUseCase(outputPort, gateway);
    return { useCase, gateway, outputPort, channel, getDisconnected: () => disconnected, getRejected: () => rejected };
  }

  it('subscribes via gateway and forwards messages to output port', () => {
    let received: ((message: { status?: string }) => void) | undefined;
    const channel = { unsubscribe: vi.fn() };
    const gateway = {
      subscribe: vi.fn(
        (_planId: number, callbacks: { received: (message: { status?: string }) => void }) => {
          received = callbacks.received;
          return channel;
        }
      )
    } as unknown as PlanOptimizationGateway;
    const outputPort: SubscribePlanOptimizationOutputPort = {
      present: vi.fn(),
      presentConnectionLost: vi.fn()
    };
    const useCase = new SubscribePlanOptimizationUseCase(outputPort, gateway);
    const onSubscribed = vi.fn();

    useCase.execute({ planId: 7, onSubscribed });

    expect(gateway.subscribe).toHaveBeenCalledWith(7, expect.any(Object));
    expect(onSubscribed).toHaveBeenCalledWith(channel);
    received?.({ status: 'optimizing' });
    expect(outputPort.present).toHaveBeenCalledWith({ status: 'optimizing' });
  });

  it('forwards disconnected to presentConnectionLost', () => {
    const { useCase, outputPort, getDisconnected } = createHarness();

    useCase.execute({ planId: 7 });
    getDisconnected()?.();

    expect(outputPort.presentConnectionLost).toHaveBeenCalledTimes(1);
  });

  it('forwards rejected to presentConnectionLost', () => {
    const { useCase, outputPort, getRejected } = createHarness();

    useCase.execute({ planId: 7 });
    getRejected()?.();

    expect(outputPort.presentConnectionLost).toHaveBeenCalledTimes(1);
  });
});
