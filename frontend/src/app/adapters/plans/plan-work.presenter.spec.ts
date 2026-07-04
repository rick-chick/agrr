import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanWorkView } from '../../components/plans/plan-work.view';
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

const baseControl = {
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
  completingItemId: null as number | null,
  regenerating: false,
  regenerateError: null,
  pendingSyncToastKey: null,
  pendingRecordSavedToastKey: null,
  pendingRecordSavedEvent: null,
  pendingQuickCompleteValidation: null,
  syncReloadNonce: 0
};

describe('PlanWorkPresenter quick complete', () => {
  let presenter: PlanWorkPresenter;
  let view: PlanWorkView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanWorkPresenter]
    });

    presenter = TestBed.inject(PlanWorkPresenter);
    view = {
      control: {
        ...baseControl,
        completingItemId: 11
      }
    };
    presenter.setView(view);
  });

  it('queues record saved toast and pending saved event on quick complete success', () => {
    presenter.onSuccess({ workRecord });

    expect(view.control.pendingRecordSavedToastKey).toBe('plans.work.toast.record_saved');
    expect(view.control.pendingRecordSavedEvent).toEqual({
      workRecord,
      mode: 'create-from-item'
    });
    expect(view.control.completingItemId).toBeNull();
  });

  it('queues validation sheet state on quick complete validation error', () => {
    presenter.onValidationError({ fieldErrors: { actual_date: ['required'] } });

    expect(view.control.completingItemId).toBeNull();
    expect(view.control.pendingQuickCompleteValidation).toEqual({
      itemId: 11,
      fieldErrors: { actual_date: ['required'] }
    });
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

  it('clears regenerate error on regenerate success', () => {
    view.control = {
      ...view.control,
      regenerating: true,
      regenerateError: 'plans.task_schedules.sync_errors.generic'
    };

    presenter.onRegenerateSuccess();

    expect(view.control.regenerateError).toBeNull();
  });
});

describe('PlanWorkPresenter skip success', () => {
  let presenter: PlanWorkPresenter;
  let view: PlanWorkView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanWorkPresenter]
    });

    presenter = TestBed.inject(PlanWorkPresenter);
    view = { control: { ...baseControl } };
    presenter.setView(view);
  });

  it('requests list reload via syncReloadNonce when skip succeeds', () => {
    presenter.onSuccess();

    expect(view.control.syncReloadNonce).toBe(1);
  });
});

describe('PlanWorkPresenter load error', () => {
  let presenter: PlanWorkPresenter;
  let view: PlanWorkView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanWorkPresenter]
    });

    presenter = TestBed.inject(PlanWorkPresenter);
    view = { control: { ...baseControl } };
    presenter.setView(view);
  });

  it('surfaces load errors and clears list data', () => {
    presenter.onError({ message: 'common.api_error.generic' });

    expect(view.control.loading).toBe(false);
    expect(view.control.error).toBe('common.api_error.generic');
    expect(view.control.plan).toBeNull();
    expect(view.control.today).toEqual([]);
  });
});

describe('PlanWorkPresenter regenerate error', () => {
  let presenter: PlanWorkPresenter;
  let view: PlanWorkView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanWorkPresenter]
    });

    presenter = TestBed.inject(PlanWorkPresenter);
    view = { control: { ...baseControl, regenerating: true } };
    presenter.setView(view);
  });

  it('stores regenerate error and stops regenerating', () => {
    presenter.onRegenerateError({ message: 'plans.task_schedules.sync_errors.generic' });

    expect(view.control.regenerating).toBe(false);
    expect(view.control.regenerateError).toBe('plans.task_schedules.sync_errors.generic');
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
        ...baseControl,
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
        }
      }
    };
    presenter.setView(view);
  });

  it('ignores sync updates when plan is not loaded yet', () => {
    view.control = { ...baseControl, plan: null };

    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null, syncErrorCropId: null });

    expect(view.control.syncReloadNonce).toBe(0);
    expect(view.control.pendingSyncToastKey).toBeNull();
  });

  it('updates plan sync state and queues toast/reload when ready', () => {
    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null, syncErrorCropId: null });

    expect(view.control.plan?.task_schedule_sync_state).toBe('ready');
    expect(view.control.regenerating).toBe(false);
    expect(view.control.pendingSyncToastKey).toBe('plans.task_schedules.sync_updated');
    expect(view.control.syncReloadNonce).toBe(1);
  });

  it('queues reload without toast when failed', () => {
    presenter.onTaskScheduleSync({
      syncState: 'failed',
      syncError: 'plans.task_schedules.sync_errors.agrr_unavailable',
      syncErrorCropId: null
    });

    expect(view.control.plan?.task_schedule_sync_state).toBe('failed');
    expect(view.control.plan?.task_schedule_sync_error).toBe(
      'plans.task_schedules.sync_errors.agrr_unavailable'
    );
    expect(view.control.regenerating).toBe(false);
    expect(view.control.pendingSyncToastKey).toBeNull();
    expect(view.control.syncReloadNonce).toBe(1);
  });

  it('sets recentAdHocRecord from loaded work day list data', () => {
    presenter.present({
      plan: view.control.plan!,
      fields: [],
      overdue: [],
      today: [],
      upcoming: [],
      recentAdHocRecord: { name: '規格選別', actualDate: '2026-06-12' }
    });

    expect(view.control.recentAdHocRecord).toEqual({
      name: '規格選別',
      actualDate: '2026-06-12'
    });
  });
});
