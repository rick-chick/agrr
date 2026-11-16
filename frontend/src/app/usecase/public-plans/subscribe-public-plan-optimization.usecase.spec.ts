import { describe, expect, it, vi } from 'vitest';
import { SubscribePublicPlanOptimizationUseCase } from './subscribe-public-plan-optimization.usecase';
import { PublicPlanOptimizationGateway } from './public-plan-optimization-gateway';
import { SubscribePublicPlanOptimizationOutputPort } from './subscribe-public-plan-optimization.output-port';

describe('SubscribePublicPlanOptimizationUseCase', () => {
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
    } as unknown as PublicPlanOptimizationGateway;
    const outputPort: SubscribePublicPlanOptimizationOutputPort = {
      present: vi.fn(),
      presentConnectionLost: vi.fn()
    };
    const useCase = new SubscribePublicPlanOptimizationUseCase(outputPort, gateway);
    return {
      useCase,
      gateway,
      outputPort,
      channel,
      getDisconnected: () => disconnected,
      getRejected: () => rejected
    };
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
    } as unknown as PublicPlanOptimizationGateway;
    const outputPort: SubscribePublicPlanOptimizationOutputPort = {
      present: vi.fn(),
      presentConnectionLost: vi.fn()
    };
    const useCase = new SubscribePublicPlanOptimizationUseCase(outputPort, gateway);
    const onSubscribed = vi.fn();

    useCase.execute({ planId: 12, onSubscribed });

    expect(gateway.subscribe).toHaveBeenCalledWith(12, expect.any(Object));
    expect(onSubscribed).toHaveBeenCalledWith(channel);
    received?.({ status: 'optimizing' });
    expect(outputPort.present).toHaveBeenCalledWith({ status: 'optimizing' });
  });

  it('forwards disconnected to presentConnectionLost', () => {
    const { useCase, outputPort, getDisconnected } = createHarness();

    useCase.execute({ planId: 12 });
    getDisconnected()?.();

    expect(outputPort.presentConnectionLost).toHaveBeenCalledTimes(1);
  });

  it('forwards rejected to presentConnectionLost', () => {
    const { useCase, outputPort, getRejected } = createHarness();

    useCase.execute({ planId: 12 });
    getRejected()?.();

    expect(outputPort.presentConnectionLost).toHaveBeenCalledTimes(1);
  });
});