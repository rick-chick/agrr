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
      fieldCultivationFilterId: null,
      monthGroups: [],
      fieldFilterOptions: [],
      cropIdsForBanner: [],
      cropNamesForBanner: {},
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
    expect(view.control.monthGroups).toHaveLength(2);
    expect(view.control.monthGroups[0]?.rows[0]?.item.name).toBe('Weeding');
    expect(view.control.fieldFilterOptions).toEqual(
      expect.arrayContaining([
        { value: 10, label: 'North' },
        { value: 20, label: 'South' }
      ])
    );
    expect(view.control.cropIdsForBanner).toEqual(expect.arrayContaining([20, 30]));
    expect(view.control.cropNamesForBanner[20]).toBe('Tomato');
    expect(view.control.cropNamesForBanner[30]).toBe('Carrot');
  });

  it('includes item details in month groups without hydrate', () => {
    const schedule: TaskScheduleResponse = {
      ...scheduleWithFields,
      fields: [
        field({
          field_cultivation_id: 10,
          name: 'North',
          schedules: {
            general: [
              task({
                item_id: 1,
                name: 'Weeding',
                scheduled_date: '2026-06-10',
                field_cultivation_id: 10,
                details: {
                  stage: { name: 'Vegetative', order: 2 },
                  gdd: { trigger: '150', tolerance: '5' },
                  priority: 1,
                  weather_dependency: 'low',
                  time_per_sqm: '0',
                  amount: '20',
                  amount_unit: 'kg',
                  source: 'blueprint',
                  master: {
                    name: 'Weed master',
                    description: 'Pull weeds carefully',
                    time_per_sqm: '0',
                    weather_dependency: 'low',
                    required_tools: [],
                    skill_level: 'beginner',
                    task_type: 'field_work'
                  },
                  history: { rescheduled_at: null, cancelled_at: null }
                }
              })
            ],
            fertilizer: [],
            unscheduled: []
          }
        })
      ]
    };

    presenter.present({ schedule });

    const details = view.control.monthGroups[0]?.rows[0]?.item.details;
    expect(details).toEqual({
      stageName: 'Vegetative',
      gddTrigger: '150',
      gddTolerance: '5',
      amount: '20',
      amountUnit: 'kg',
      masterName: 'Weed master',
      masterDescription: 'Pull weeds carefully'
    });
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

  it('applyClientFilters filters month groups by field cultivation id', () => {
    presenter.present({ schedule: scheduleWithFields });

    presenter.applyClientFilters('2026-01-01', 10);

    expect(view.control.fieldCultivationFilterId).toBe(10);
    expect(view.control.fromDate).toBe('2026-01-01');
    expect(view.control.monthGroups).toHaveLength(1);
    expect(view.control.monthGroups[0]?.rows).toHaveLength(1);
    expect(view.control.monthGroups[0]?.rows[0]?.item.name).toBe('Weeding');
    expect(view.control.fieldFilterOptions).toEqual(
      expect.arrayContaining([
        { value: 10, label: 'North' },
        { value: 20, label: 'South' }
      ])
    );
  });

  it('applyClientFilters filters month groups by from date', () => {
    presenter.present({ schedule: scheduleWithFields });

    presenter.applyClientFilters('2026-07-01', null);

    expect(view.control.monthGroups).toHaveLength(1);
    expect(view.control.monthGroups[0]?.rows[0]?.item.name).toBe('Harvest');
  });

  it('applyClientFilters stores filter state before schedule is loaded', () => {
    presenter.applyClientFilters(localTodayIso(), 42);

    expect(view.control.fromDate).toBe(localTodayIso());
    expect(view.control.fieldCultivationFilterId).toBe(42);
    expect(view.control.monthGroups).toEqual([]);
  });

  it('recomputes derived fields on task schedule sync', () => {
    presenter.present({ schedule: scheduleWithFields });
    presenter.applyClientFilters('2026-01-01', 10);

    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null, syncErrorCropId: null });

    expect(view.control.monthGroups).toHaveLength(1);
    expect(view.control.monthGroups[0]?.rows[0]?.item.name).toBe('Weeding');
    expect(view.control.cropIdsForBanner).toEqual(expect.arrayContaining([20, 30]));
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

  it('ignores sync messages when schedule is not loaded', () => {
    view.control = { ...view.control, schedule: null };

    presenter.onTaskScheduleSync({ syncState: 'ready', syncError: null, syncErrorCropId: null });

    expect(view.control.syncReloadNonce).toBe(0);
    expect(view.control.pendingSyncToastKey).toBeNull();
  });
});
