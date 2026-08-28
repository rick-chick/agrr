import { describe, expect, it, vi } from 'vitest';
import { PublicPlanOptimizationChannelGateway } from './public-plan-optimization.gateway';
import { OptimizationService } from '../../services/plans/optimization.service';

describe('PublicPlanOptimizationChannelGateway', () => {
  it('forwards disconnected and rejected callbacks to OptimizationService', () => {
    let disconnected: (() => void) | undefined;
    let rejected: (() => void) | undefined;
    const optimizationService = {
      subscribe: vi.fn(
        (
          channel: string,
          params: Record<string, unknown>,
          callbacks: { received: () => void; disconnected?: () => void; rejected?: () => void }
        ) => {
          disconnected = callbacks.disconnected;
          rejected = callbacks.rejected;
          return { unsubscribe: vi.fn() };
        }
      )
    };
    const gateway = new PublicPlanOptimizationChannelGateway(
      optimizationService as unknown as OptimizationService
    );
    const onDisconnected = vi.fn();
    const onRejected = vi.fn();

    gateway.subscribe(9, {
      received: vi.fn(),
      disconnected: onDisconnected,
      rejected: onRejected
    });

    expect(optimizationService.subscribe).toHaveBeenCalledWith(
      'OptimizationChannel',
      { cultivation_plan_id: 9 },
      expect.objectContaining({
        disconnected: expect.any(Function),
        rejected: expect.any(Function)
      })
    );
    disconnected?.();
    rejected?.();
    expect(onDisconnected).toHaveBeenCalledTimes(1);
    expect(onRejected).toHaveBeenCalledTimes(1);
  });
});
