import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanTaskScheduleView } from '../../components/plans/plan-task-schedule.view';
import type { FieldSchedule, PlanInfo, TaskScheduleItem } from '../../models/plans/task-schedule';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { localTodayIso } from '../../core/local-today';
import { PlanTaskSchedulePresenter } from './plan-task-schedule.presenter';
import { PlanTaskScheduleDataDto } from '../../usecase/plans/load-plan-task-schedule.dtos';

function task(
  overrides: Partial<TaskScheduleItem> & Pick<TaskScheduleItem, 'item_id' | 'name' | 'scheduled_date'>
): TaskScheduleItem {
  return {
    item_id: overrides.item_id,
    name: overrides.name,
    scheduled_date: overrides.scheduled_date,
    task_type: 'general',
    category: 'general',
    priority: 1,
    source: 'blueprint',
    weather_dependency: 'low',
    time_per_sqm: '0',
    amount: '',
    amount_unit: '',
    status: 'planned',
    agricultural_task_id: 1,
    field_cultivation_id: overrides.field_cultivation_id ?? 10,
    completed: false,
    work_records: [],
    details: {
      stage: { name: 'Stage', order: 1 },
      gdd: { trigger: '100', tolerance: '10' },
      priority: 1,
      weather_dependency: 'low',
      time_per_sqm: '0',
      amount: '',
      amount_unit: '',
      source: 'blueprint',
      master: null,
      history: { rescheduled_at: null, cancelled_at: null }
    },
    badge: { type: 'planned' },
    ...overrides
  };
}

function field(overrides: Partial<FieldSchedule> & Pick<FieldSchedule, 'field_cultivation_id'>): FieldSchedule {
  return {
    id: overrides.id ?? 1,
    name: overrides.name ?? 'Field A',
    crop_name: overrides.crop_name ?? 'Tomato',
    area_sqm: 100,
    field_cultivation_id: overrides.field_cultivation_id,
    crop_id: overrides.crop_id ?? 20,
    task_options: [],
    schedules: overrides.schedules ?? { general: [], fertilizer: [], unscheduled: [] }
  };
}

const planInfo: PlanInfo = {
  id: 7,
  name: 'Main Plan',
  status: 'completed',
  planning_start_date: '2026-01-01',
  planning_end_date: '2026-12-31',
  timeline_generated_at: '2026-06-01T00:00:00Z',
  timeline_generated_at_display: '2026-06-01',
  task_schedule_sync_state: 'ready',
  task_schedule_sync_error: null,
  task_schedule_sync_error_crop_id: null
};

const scheduleWithFields: TaskScheduleResponse = {
  plan: planInfo,
  week: {
    start_date: '2026-06-01',
    end_date: '2026-06-07',
    label: '2026-06-01',
    days: []
  },
  milestones: [],
  fields: [
    field({
      field_cultivation_id: 10,
      name: 'North',
      schedules: {
        general: [task({ item_id: 1, name: 'Weeding', scheduled_date: '2026-06-10', field_cultivation_id: 10 })],
        fertilizer: [],
        unscheduled: []
      }
    }),
    field({
      id: 2,
      field_cultivation_id: 20,
      name: 'South',
      crop_id: 30,
      crop_name: 'Carrot',
      schedules: {
        general: [task({ item_id: 2, name: 'Harvest', scheduled_date: '2026-07-05', field_cultivation_id: 20 })],
        fertilizer: [],
        unscheduled: []
      }
    })
  ],
  labels: {},
  minimap: { start_date: '', end_date: '', weeks: [] }
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
      fromDate: '2026-01-01',
      fieldFilterId: null,
      fieldCultivationFilterId: null,
      monthGroups: [],
      unscheduledRows: [],
      fieldFilterOptions: [],
      cropIdsForBanner: [],
      cropNamesForBanner: {},
      filteredFieldCount: 0,
      filteredTaskCount: 0,
      regenerateRequiresConfirm: false,
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
    const dto: PlanTaskScheduleDataDto = { schedule: scheduleWithFields };

    presenter.present(dto);

    expect(view.control.loading).toBe(false);
    expect(view.control.error).toBeNull();
    expect(view.control.schedule).toEqual(scheduleWithFields);
    expect(view.control.regenerating).toBe(false);
    expect(view.control.regenerateError).toBeNull();
    expect(view.control.pendingSyncToastKey).toBeNull();
    expect(view.control.syncReloadNonce).toBe(0);
  });

  it('sets error state on onError', () => {
    view.control = createView({ schedule: scheduleWithFields }).control;

    presenter.onError({ message: 'Load failed', scope: 'load-plan-task-schedule' });

    expect(view.control.loading).toBe(false);
    expect(view.control.error).toBe('Load failed');
    expect(view.control.schedule).toBeNull();
    expect(view.control.regenerating).toBe(false);
    expect(view.control.regenerateError).toBeNull();
    expect(view.control.monthGroups).toEqual([]);
    expect(view.control.fieldFilterOptions).toEqual([]);
    expect(view.control.cropIdsForBanner).toEqual([]);
    expect(view.control.cropNamesForBanner).toEqual({});
  });
});

describe('PlanTaskSchedulePresenter derived fields', () => {
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

  it('applyClientFilters stores filter state before schedule is loaded', () => {
    presenter.applyClientFilters(localTodayIso(), null, 42);

    expect(view.control.fromDate).toBe(localTodayIso());
    expect(view.control.fieldFilterId).toBeNull();
    expect(view.control.fieldCultivationFilterId).toBe(42);
    expect(view.control.monthGroups).toEqual([]);
  });

  it('recomputes derived fields on task schedule sync', () => {
    presenter.present({ schedule: scheduleWithFields });
    presenter.applyClientFilters('2026-01-01', 1, null);

    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null, syncErrorCropId: null });

    expect(view.control.schedule?.plan.task_schedule_sync_state).toBe('ready');
    expect(view.control.regenerating).toBe(false);
    expect(view.control.pendingSyncToastKey).toBe('plans.task_schedules.sync_updated');
    expect(view.control.syncReloadNonce).toBe(1);
    expect(view.control.fromDate).toBe('2026-01-01');
    expect(view.control.fieldFilterId).toBe(1);
  });

  it('adds displayStatus to month group rows', () => {
    presenter.present({ schedule: scheduleWithFields });

    expect(view.control.monthGroups[0]?.rows[0]?.displayStatus).toBe('planned');
  });

  it('computes filtered summary counts from active filters', () => {
    presenter.present({ schedule: scheduleWithFields });
    presenter.applyClientFilters('2026-06-01', 1, null);

    expect(view.control.filteredFieldCount).toBe(1);
    expect(view.control.filteredTaskCount).toBe(1);
  });

  it('sets regenerateRequiresConfirm when schedule has tasks', () => {
    presenter.present({ schedule: scheduleWithFields });

    expect(view.control.regenerateRequiresConfirm).toBe(true);
  });

  it('clears regenerateRequiresConfirm when schedule has no tasks', () => {
    presenter.present({
      schedule: {
        ...scheduleWithFields,
        fields: [
          field({
            field_cultivation_id: 10,
            schedules: { general: [], fertilizer: [], unscheduled: [] }
          })
        ]
      }
    });

    expect(view.control.regenerateRequiresConfirm).toBe(false);
  });

  it('exposes unscheduled rows and requires regenerate confirm for unscheduled-only schedules', () => {
    presenter.present({
      schedule: {
        ...scheduleWithFields,
        fields: [
          field({
            field_cultivation_id: 10,
            schedules: {
              general: [],
              fertilizer: [],
              unscheduled: [
                task({
                  item_id: 99,
                  name: 'Pending prep',
                  scheduled_date: null,
                  field_cultivation_id: 10
                })
              ]
            }
          })
        ]
      }
    });

    expect(view.control.unscheduledRows.map((row) => row.item.name)).toEqual(['Pending prep']);
    expect(view.control.monthGroups).toEqual([]);
    expect(view.control.regenerateRequiresConfirm).toBe(true);
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
    view = createView({ schedule: scheduleWithFields });
    presenter.setView(view);
  });

  it('sets regenerating when regenerate starts', () => {
    presenter.onRegenerateStarted();

    expect(view.control.regenerating).toBe(true);
    expect(view.control.regenerateError).toBeNull();
  });

  it('clears regenerate error and keeps regenerating when POST returns generating', () => {
    view.control = { ...view.control, regenerateError: 'previous error' };

    presenter.onRegenerateSuccess({ success: true, task_schedule_sync_state: 'generating' });

    expect(view.control.regenerateError).toBeNull();
    expect(view.control.regenerating).toBe(true);
    expect(view.control.schedule?.plan.task_schedule_sync_state).toBe('generating');
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
    view = createView({ schedule: scheduleWithFields });
    presenter.setView(view);
  });

  it('updates schedule plan sync state and queues toast/reload when ready', () => {
    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null, syncErrorCropId: null });

    expect(view.control.schedule?.plan.task_schedule_sync_state).toBe('ready');
    expect(view.control.regenerating).toBe(false);
    expect(view.control.pendingSyncToastKey).toBe('plans.task_schedules.sync_updated');
    expect(view.control.syncReloadNonce).toBe(1);
  });

  it('queues pending sync when schedule is not loaded and merges on present', () => {
    view.control = { ...view.control, schedule: null };

    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null, syncErrorCropId: null });

    expect(view.control.syncReloadNonce).toBe(0);
    expect(view.control.pendingSyncToastKey).toBeNull();

    presenter.present({ schedule: scheduleWithFields });

    expect(view.control.schedule?.plan.task_schedule_sync_state).toBe('ready');
    expect(view.control.pendingSyncToastKey).toBe('plans.task_schedules.sync_updated');
    expect(view.control.syncReloadNonce).toBe(1);
  });

  it('present keeps regenerating when loaded sync state is generating', () => {
    const generatingSchedule: TaskScheduleResponse = {
      ...scheduleWithFields,
      plan: { ...planInfo, task_schedule_sync_state: 'generating' }
    };

    presenter.present({ schedule: generatingSchedule });

    expect(view.control.regenerating).toBe(true);
  });

  it('present ignores stale schedule loads started before a newer reload', () => {
    view.control = {
      ...view.control,
      schedule: scheduleWithFields,
      regenerating: true
    };
    const staleSchedule: TaskScheduleResponse = {
      ...scheduleWithFields,
      plan: { ...planInfo, task_schedule_sync_state: 'ready' },
      fields: []
    };

    presenter.beginScheduleLoad();
    presenter.beginScheduleLoad();
    presenter.present({ schedule: staleSchedule, loadGeneration: 1 });

    expect(view.control.regenerating).toBe(true);
    expect(view.control.schedule?.fields.length).toBe(2);
  });
});
