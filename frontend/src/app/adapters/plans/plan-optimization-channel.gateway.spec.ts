import { describe, expect, it, vi } from 'vitest';
import { PlanOptimizationChannelGateway } from './plan-optimization-channel.gateway';
import { OptimizationService } from '../../services/plans/optimization.service';

describe('PlanOptimizationChannelGateway', () => {
  function createGateway() {
    let received: ((payload: Record<string, unknown>) => void) | undefined;
    const optimizationService = {
      subscribe: vi.fn(
        (
          channel: string,
          params: Record<string, unknown>,
          callbacks: { received: (payload: Record<string, unknown>) => void }
        ) => {
          received = callbacks.received;
          return { unsubscribe: vi.fn() };
        }
      )
    };
    const gateway = new PlanOptimizationChannelGateway(
      optimizationService as unknown as OptimizationService
    );
    return { gateway, optimizationService, getReceived: () => received };
  }

  describe('subscribe', () => {
    it('subscribes to PlansOptimizationChannel and forwards messages', () => {
      const { gateway, optimizationService, getReceived } = createGateway();
      const onReceived = vi.fn();

      gateway.subscribe(7, { received: onReceived });

      expect(optimizationService.subscribe).toHaveBeenCalledWith(
        'PlansOptimizationChannel',
        { cultivation_plan_id: 7 },
        expect.objectContaining({ received: expect.any(Function) })
      );
      getReceived()?.({ status: 'optimizing', progress: 50 });
      expect(onReceived).toHaveBeenCalledWith({ status: 'optimizing', progress: 50 });
    });
  });

  describe('subscribeTaskScheduleSync', () => {
    it('subscribes to PlansOptimizationChannel and parses task_schedule_sync payloads', () => {
      const { gateway, optimizationService, getReceived } = createGateway();
      const onReceived = vi.fn();

      gateway.subscribeTaskScheduleSync(7, { received: onReceived });

      expect(optimizationService.subscribe).toHaveBeenCalledWith(
        'PlansOptimizationChannel',
        { cultivation_plan_id: 7 },
        expect.objectContaining({ received: expect.any(Function) })
      );

      getReceived()?.({ status: 'optimizing', progress: 50 });
      expect(onReceived).not.toHaveBeenCalled();

      getReceived()?.({
        type: 'task_schedule_sync',
        task_schedule_sync_state: 'ready',
        task_schedule_sync_error: null
      });
      expect(onReceived).toHaveBeenCalledWith({
        syncState: 'ready',
        syncError: null,
        syncErrorCropId: null
      });
    });

    it('ignores task_schedule_sync payloads without task_schedule_sync_state', () => {
      const { gateway, getReceived } = createGateway();
      const onReceived = vi.fn();

      gateway.subscribeTaskScheduleSync(7, { received: onReceived });
      getReceived()?.({
        type: 'task_schedule_sync',
        task_schedule_sync_error: 'timeout'
      });

      expect(onReceived).not.toHaveBeenCalled();
    });

    it('forwards sync error from cable payload', () => {
      const { gateway, getReceived } = createGateway();
      const onReceived = vi.fn();

      gateway.subscribeTaskScheduleSync(7, { received: onReceived });
      getReceived()?.({
        type: 'task_schedule_sync',
        task_schedule_sync_state: 'failed',
        task_schedule_sync_error: 'plans.task_schedules.sync_errors.agrr_unavailable'
      });

      expect(onReceived).toHaveBeenCalledWith({
        syncState: 'failed',
        syncError: 'plans.task_schedules.sync_errors.agrr_unavailable',
        syncErrorCropId: null
      });
    });

    it('forwards sync error crop id from cable payload', () => {
      const { gateway, getReceived } = createGateway();
      const onReceived = vi.fn();

      gateway.subscribeTaskScheduleSync(7, { received: onReceived });
      getReceived()?.({
        type: 'task_schedule_sync',
        task_schedule_sync_state: 'failed',
        task_schedule_sync_error: 'plans.task_schedules.sync_errors.missing_crop_blueprints',
        task_schedule_sync_error_crop_id: 15
      });

      expect(onReceived).toHaveBeenCalledWith({
        syncState: 'failed',
        syncError: 'plans.task_schedules.sync_errors.missing_crop_blueprints',
        syncErrorCropId: 15
      });
    });

    it('normalizes legacy raw sync error from cable payload', () => {
      const { gateway, getReceived } = createGateway();
      const onReceived = vi.fn();

      gateway.subscribeTaskScheduleSync(7, { received: onReceived });
      getReceived()?.({
        type: 'task_schedule_sync',
        task_schedule_sync_state: 'failed',
        task_schedule_sync_error: 'worker timeout'
      });

      expect(onReceived).toHaveBeenCalledWith({
        syncState: 'failed',
        syncError: 'plans.task_schedules.sync_errors.generic',
        syncErrorCropId: null
      });
    });
  });
});
