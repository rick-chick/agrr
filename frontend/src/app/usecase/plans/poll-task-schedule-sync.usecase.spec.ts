import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { of } from 'rxjs';
import { PollTaskScheduleSyncUseCase } from './poll-task-schedule-sync.usecase';
import { PlanGateway } from './plan-gateway';
import { SubscribeTaskScheduleSyncOutputPort } from './subscribe-task-schedule-sync.output-port';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { TASK_SCHEDULE_SYNC_POLL_INTERVAL_MS } from './task-schedule-sync-lifecycle';

function scheduleWithSyncState(syncState: string): TaskScheduleResponse {
  return {
    plan: {
      id: 7,
      name: 'Plan',
      status: 'completed',
      planning_start_date: '2026-01-01',
      planning_end_date: '2026-12-31',
      timeline_generated_at: '2026-06-01T00:00:00Z',
      timeline_generated_at_display: '2026-06-01',
      task_schedule_sync_state: syncState,
      task_schedule_sync_error: null,
      task_schedule_sync_error_crop_id: null
    },
    week: { start_date: '2026-06-01', end_date: '2026-06-07', label: 'week' },
    milestones: [],
    fields: [],
    labels: {},
    minimap: { start_date: '', end_date: '', weeks: [] }
  };
}

describe('PollTaskScheduleSyncUseCase', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('polls until sync state leaves generating and notifies output port', () => {
    const getTaskSchedule = vi
      .fn()
      .mockReturnValueOnce(of(scheduleWithSyncState('generating')))
      .mockReturnValue(of(scheduleWithSyncState('ready')));
    const gateway = { getTaskSchedule } as unknown as PlanGateway;
    const outputPort: SubscribeTaskScheduleSyncOutputPort = {
      onTaskScheduleSync: vi.fn()
    };
    const useCase = new PollTaskScheduleSyncUseCase(outputPort, gateway);

    const subscription = useCase.execute({ planId: 7 });
    vi.advanceTimersByTime(0);
    vi.advanceTimersByTime(TASK_SCHEDULE_SYNC_POLL_INTERVAL_MS);
    subscription.unsubscribe();

    expect(getTaskSchedule).toHaveBeenCalledWith(7);
    expect(outputPort.onTaskScheduleSync).toHaveBeenCalledWith({
      syncState: 'ready',
      syncError: null,
      syncErrorCropId: null
    });
  });
});
