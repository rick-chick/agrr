import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanWorkView } from '../../components/plans/plan-work.view';
import { WorkRecordSheetSavedEvent } from '../../components/plans/work-record-sheet.view';
import { WorkRecord } from '../../models/plans/work-record';
import { PlanWorkPresenter } from './plan-work.presenter';

const workRecord: WorkRecord = {
  id: 1,
  cultivation_plan_id: 7,
  field_cultivation_id: 10,
  task_schedule_item_id: 11,
  agricultural_task_id: null,
  name: '追肥',
  task_type: null,
  actual_date: '2026-06-25',
  amount: null,
  amount_unit: null,
  time_spent_minutes: null,
  notes: null,
  created_at: '2026-06-25',
  updated_at: '2026-06-25',
  task_schedule_item: null
};

describe('PlanWorkPresenter quick complete', () => {
  let presenter: PlanWorkPresenter;
  let view: PlanWorkView;
  let onRecordSavedCallback: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    onRecordSavedCallback = vi.fn();

    TestBed.configureTestingModule({
      providers: [PlanWorkPresenter]
    });

    presenter = TestBed.inject(PlanWorkPresenter);
    view = {
      control: {
        loading: false,
        error: null,
        plan: null,
        fields: [],
        overdue: [],
        today: [],
        upcoming: [],
        includeSkipped: false,
        recentAdHocRecord: null,
        highlightedItemId: null,
        completingItemId: 11,
        regenerating: false,
        regenerateError: null,
        pendingSyncToastKey: null,
        pendingRecordSavedToastKey: null,
        syncReloadNonce: 0
      }
    };
    presenter.setView(view);
    presenter.onRecordSavedCallback = onRecordSavedCallback as (event: WorkRecordSheetSavedEvent) => void;
  });

  it('queues record saved toast and emits saved event on quick complete success', () => {
    presenter.onSuccess({ workRecord });

    expect(view.control.pendingRecordSavedToastKey).toBe('plans.work.toast.record_saved');
    expect(onRecordSavedCallback).toHaveBeenCalledWith({
      workRecord,
      mode: 'create-from-item'
    });
    expect(view.control.completingItemId).toBeNull();
  });

  it('clears completingItemId on quick complete error', () => {
    presenter.onError({ message: 'common.api_error.generic' });

    expect(view.control.completingItemId).toBeNull();
    expect(view.control.error).toBe('common.api_error.generic');
  });

  it('sets regenerating when regenerate starts', () => {
    presenter.onRegenerateStarted();

    expect(view.control.regenerating).toBe(true);
    expect(view.control.regenerateError).toBeNull();
  });
});

describe('PlanWorkPresenter task schedule sync', () => {
  let presenter: PlanWorkPresenter;
  let view: PlanWorkView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanWorkPresenter]
    });

    presenter = TestBed.inject(PlanWorkPresenter);
    view = {
      control: {
        loading: false,
        error: null,
        plan: {
          id: 7,
          name: 'テスト計画',
          status: 'completed',
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          timeline_generated_at: '2026-06-01T00:00:00Z',
          timeline_generated_at_display: '2026-06-01',
          task_schedule_sync_state: 'stale',
          task_schedule_sync_error: null
        },
        fields: [],
        overdue: [],
        today: [],
        upcoming: [],
        includeSkipped: false,
        recentAdHocRecord: null,
        highlightedItemId: null,
        completingItemId: null,
        regenerating: false,
        regenerateError: null,
        pendingSyncToastKey: null,
        pendingRecordSavedToastKey: null,
        syncReloadNonce: 0
      }
    };
    presenter.setView(view);
  });

  it('updates plan sync state and queues toast/reload when ready', () => {
    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null });

    expect(view.control.plan?.task_schedule_sync_state).toBe('ready');
    expect(view.control.regenerating).toBe(false);
    expect(view.control.pendingSyncToastKey).toBe('plans.task_schedules.sync_updated');
    expect(view.control.syncReloadNonce).toBe(1);
  });

  it('queues reload without toast when failed', () => {
    presenter.onTaskScheduleSync({
      syncState: 'failed',
      syncError: 'plans.task_schedules.sync_errors.agrr_unavailable'
    });

    expect(view.control.plan?.task_schedule_sync_state).toBe('failed');
    expect(view.control.plan?.task_schedule_sync_error).toBe(
      'plans.task_schedules.sync_errors.agrr_unavailable'
    );
    expect(view.control.regenerating).toBe(false);
    expect(view.control.pendingSyncToastKey).toBeNull();
    expect(view.control.syncReloadNonce).toBe(1);
  });
});
