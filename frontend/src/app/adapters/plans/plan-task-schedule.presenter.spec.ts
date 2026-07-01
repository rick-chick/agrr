import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanTaskScheduleView } from '../../components/plans/plan-task-schedule.view';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { PlanTaskSchedulePresenter } from './plan-task-schedule.presenter';

const loadedSchedule: TaskScheduleResponse = {
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
  week: {
    start_date: '2026-06-01',
    end_date: '2026-06-07',
    label: '2026-06-01',
    days: []
  },
  milestones: [],
  fields: [],
  labels: {},
  minimap: {}
};

describe('PlanTaskSchedulePresenter regenerate', () => {
  let presenter: PlanTaskSchedulePresenter;
  let view: PlanTaskScheduleView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanTaskSchedulePresenter]
    });

    presenter = TestBed.inject(PlanTaskSchedulePresenter);
    view = {
      control: {
        loading: false,
        error: null,
        schedule: loadedSchedule,
        regenerating: false,
        regenerateError: null,
        pendingSyncToastKey: null,
        syncReloadNonce: 0
      }
    };
    presenter.setView(view);
  });

  it('sets regenerating when regenerate starts', () => {
    presenter.onRegenerateStarted();

    expect(view.control.regenerating).toBe(true);
    expect(view.control.regenerateError).toBeNull();
  });
});

describe('PlanTaskSchedulePresenter task schedule sync', () => {
  let presenter: PlanTaskSchedulePresenter;
  let view: PlanTaskScheduleView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanTaskSchedulePresenter]
    });

    presenter = TestBed.inject(PlanTaskSchedulePresenter);
    view = {
      control: {
        loading: false,
        error: null,
        schedule: loadedSchedule,
        regenerating: false,
        regenerateError: null,
        pendingSyncToastKey: null,
        syncReloadNonce: 0
      }
    };
    presenter.setView(view);
  });

  it('updates schedule plan sync state and queues toast/reload when ready', () => {
    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null });

    expect(view.control.schedule?.plan.task_schedule_sync_state).toBe('ready');
    expect(view.control.regenerating).toBe(false);
    expect(view.control.pendingSyncToastKey).toBe('plans.task_schedules.sync_updated');
    expect(view.control.syncReloadNonce).toBe(1);
  });

  it('ignores sync messages when schedule is not loaded', () => {
    view.control = { ...view.control, schedule: null };

    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null });

    expect(view.control.syncReloadNonce).toBe(0);
    expect(view.control.pendingSyncToastKey).toBeNull();
  });
});
