import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanTaskScheduleView } from '../../components/plans/plan-task-schedule.view';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { PlanTaskSchedulePresenter } from './plan-task-schedule.presenter';
import { PlanTaskScheduleDataDto } from '../../usecase/plans/load-plan-task-schedule.dtos';

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
    task_schedule_sync_error: null,
    task_schedule_sync_error_crop_id: null
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

function createView(overrides: Partial<PlanTaskScheduleView['control']> = {}): PlanTaskScheduleView {
  return {
    control: {
      loading: true,
      error: null,
      schedule: null,
      regenerating: false,
      regenerateError: null,
      pendingSyncToastKey: null,
      syncReloadNonce: 0,
      ...overrides
    }
  };
}

describe('PlanTaskSchedulePresenter load', () => {
  let presenter: PlanTaskSchedulePresenter;
  let view: PlanTaskScheduleView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanTaskSchedulePresenter]
    });
    presenter = TestBed.inject(PlanTaskSchedulePresenter);
    view = createView();
    presenter.setView(view);
  });

  it('presents schedule and clears sync toast state', () => {
    const dto: PlanTaskScheduleDataDto = { schedule: loadedSchedule };

    presenter.present(dto);

    expect(view.control.loading).toBe(false);
    expect(view.control.error).toBeNull();
    expect(view.control.schedule).toEqual(loadedSchedule);
    expect(view.control.regenerating).toBe(false);
    expect(view.control.regenerateError).toBeNull();
    expect(view.control.pendingSyncToastKey).toBeNull();
    expect(view.control.syncReloadNonce).toBe(0);
  });

  it('sets error state on onError', () => {
    view.control = createView({ schedule: loadedSchedule }).control;

    presenter.onError({ message: 'Load failed', scope: 'load-plan-task-schedule' });

    expect(view.control.loading).toBe(false);
    expect(view.control.error).toBe('Load failed');
    expect(view.control.schedule).toBeNull();
    expect(view.control.regenerating).toBe(false);
    expect(view.control.regenerateError).toBeNull();
  });
});

describe('PlanTaskSchedulePresenter regenerate', () => {
  let presenter: PlanTaskSchedulePresenter;
  let view: PlanTaskScheduleView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanTaskSchedulePresenter]
    });
    presenter = TestBed.inject(PlanTaskSchedulePresenter);
    view = createView({ schedule: loadedSchedule });
    presenter.setView(view);
  });

  it('sets regenerating when regenerate starts', () => {
    presenter.onRegenerateStarted();

    expect(view.control.regenerating).toBe(true);
    expect(view.control.regenerateError).toBeNull();
  });

  it('clears regenerate error on onRegenerateSuccess', () => {
    view.control = { ...view.control, regenerateError: 'previous error' };

    presenter.onRegenerateSuccess();

    expect(view.control.regenerateError).toBeNull();
  });

  it('sets regenerate error on onRegenerateError', () => {
    presenter.onRegenerateError({ message: 'Regen failed', scope: 'regenerate-task-schedule' });

    expect(view.control.regenerating).toBe(false);
    expect(view.control.regenerateError).toBe('Regen failed');
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
    view = createView({ schedule: loadedSchedule });
    presenter.setView(view);
  });

  it('updates schedule plan sync state and queues toast/reload when ready', () => {
    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null, syncErrorCropId: null });

    expect(view.control.schedule?.plan.task_schedule_sync_state).toBe('ready');
    expect(view.control.regenerating).toBe(false);
    expect(view.control.pendingSyncToastKey).toBe('plans.task_schedules.sync_updated');
    expect(view.control.syncReloadNonce).toBe(1);
  });

  it('ignores sync messages when schedule is not loaded', () => {
    view.control = { ...view.control, schedule: null };

    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null, syncErrorCropId: null });

    expect(view.control.syncReloadNonce).toBe(0);
    expect(view.control.pendingSyncToastKey).toBeNull();
  });
});
