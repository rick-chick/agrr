import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import {
  findNextScheduled,
  findTodayAdHocRecord,
  LoadWorkDayListUseCase
} from './load-work-day-list.usecase';
import { PlanGateway } from './plan-gateway';
import { LoadWorkDayListOutputPort } from './load-work-day-list.output-port';
import { LoadWorkDayListDataDto } from './load-work-day-list.dtos';
import { TaskScheduleItem, TaskScheduleResponse } from '../../models/plans/task-schedule';
import { WorkRecord } from '../../models/plans/work-record';
import { WorkRecordGateway } from './work-record-gateway';

const baseDetails = {
  stage: { name: 'stage', order: 1 },
  gdd: { trigger: '0', tolerance: '0' },
  priority: 1,
  weather_dependency: 'low',
  time_per_sqm: '1',
  amount: '1',
  amount_unit: 'kg',
  source: 'agrr',
  master: null,
  history: { rescheduled_at: null, cancelled_at: null }
};

function item(overrides: Partial<TaskScheduleItem> & { item_id: number; scheduled_date: string | null }): TaskScheduleItem {
  return {
    name: '作業',
    task_type: 'general',
    category: 'general',
    stage_name: 'stage',
    stage_order: 1,
    gdd_trigger: '0',
    gdd_tolerance: '0',
    priority: 1,
    source: 'agrr',
    weather_dependency: 'low',
    time_per_sqm: '1',
    amount: '1',
    amount_unit: 'kg',
    status: 'planned',
    agricultural_task_id: 1,
    field_cultivation_id: 10,
    completed: false,
    work_records: [],
    details: baseDetails,
    badge: { type: 'task', priority_level: 'normal', status: 'planned', category: 'general' },
    ...overrides
  };
}

function scheduleWithItems(items: TaskScheduleItem[]): TaskScheduleResponse {
  return {
    plan: {
      id: 1,
      name: 'Plan',
      status: 'active',
      planning_start_date: '2026-01-01',
      planning_end_date: '2026-12-31',
      timeline_generated_at: '2026-06-01',
      timeline_generated_at_display: '2026-06-01',
      task_schedule_sync_state: 'ready',
      task_schedule_sync_error: null,
      task_schedule_sync_error_crop_id: null
    },
    week: { start_date: '2026-06-08', end_date: '2026-06-14', label: 'week', days: [] },
    milestones: [],
    fields: [
      {
        id: 1,
        name: '第1圃場',
        crop_name: 'トマト',
        area_sqm: 100,
        field_cultivation_id: 10,
        crop_id: 1,
        task_options: [],
        schedules: { general: items, fertilizer: [], unscheduled: [] }
      }
    ],
    labels: {},
    minimap: { start_date: '', end_date: '', weeks: [] }
  };
}

describe('LoadWorkDayListUseCase', () => {
  const today = '2026-06-12';

  const createGateway = (response: TaskScheduleResponse): PlanGateway =>
    ({
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of(response),
      regenerateTaskSchedule: () => of(undefined),
      deletePlan: () => of({} as never)
    }) as PlanGateway;

  const createWorkRecordGateway = (records: WorkRecord[] = []): WorkRecordGateway =>
    ({
      listWorkRecords: () => of({ work_records: records }),
      createWorkRecord: () => of({} as never),
      updateWorkRecord: () => of({} as never),
      deleteWorkRecord: () => of({} as never),
      skipTaskScheduleItem: () => of({} as never),
      unskipTaskScheduleItem: () => of({} as never)
    }) as WorkRecordGateway;

  const adhocRecord = (overrides: Partial<WorkRecord> & { actual_date: string; name: string }): WorkRecord => ({
    id: 1,
    cultivation_plan_id: 1,
    field_cultivation_id: null,
    task_schedule_item_id: null,
    agricultural_task_id: null,
    name: overrides.name,
    task_type: null,
    actual_date: overrides.actual_date,
    amount: null,
    amount_unit: null,
    time_spent_minutes: null,
    notes: null,
    created_at: overrides.created_at ?? overrides.actual_date,
    updated_at: overrides.updated_at ?? overrides.actual_date,
    task_schedule_item: null,
    ...overrides
  });

  it('groups overdue, today, and upcoming items', () => {
    const response = scheduleWithItems([
      item({ item_id: 1, scheduled_date: '2026-06-08', name: '追肥' }),
      item({ item_id: 2, scheduled_date: '2026-06-12', name: '防除' }),
      item({ item_id: 3, scheduled_date: '2026-06-14', name: '収穫' })
    ]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway()
    );
    useCase.execute({ planId: 1, today });

    expect(result!.overdue).toHaveLength(1);
    expect(result!.overdue[0].item.item_id).toBe(1);
    expect(result!.today).toHaveLength(1);
    expect(result!.today[0].item.item_id).toBe(2);
    expect(result!.upcoming).toHaveLength(1);
    expect(result!.upcoming[0].item.item_id).toBe(3);
  });

  it('excludes skipped items by default', () => {
    const response = scheduleWithItems([
      item({ item_id: 1, scheduled_date: '2026-06-12', status: 'skipped' })
    ]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway()
    );
    useCase.execute({ planId: 1, today });

    expect(result!.overdue).toHaveLength(0);
    expect(result!.today).toHaveLength(0);
    expect(result!.upcoming).toHaveLength(0);
  });

  it('includes skipped items when includeSkipped is true', () => {
    const response = scheduleWithItems([
      item({ item_id: 1, scheduled_date: '2026-06-12', status: 'skipped' })
    ]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway()
    );
    useCase.execute({ planId: 1, today, includeSkipped: true });

    expect(result!.today).toHaveLength(1);
    expect(result!.today[0].item.status).toBe('skipped');
  });

  it('includes overdue skipped items when includeSkipped is true', () => {
    const response = scheduleWithItems([
      item({ item_id: 1, scheduled_date: '2026-06-08', status: 'skipped', name: '期限超過skip' })
    ]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway()
    );
    useCase.execute({ planId: 1, today, includeSkipped: true });

    expect(result!.overdue).toHaveLength(1);
    expect(result!.overdue[0].item.item_id).toBe(1);
    expect(result!.overdue[0].item.status).toBe('skipped');
    expect(result!.today).toHaveLength(0);
    expect(result!.upcoming).toHaveLength(0);
  });

  it('includes upcoming skipped items when includeSkipped is true', () => {
    const response = scheduleWithItems([
      item({ item_id: 2, scheduled_date: '2026-06-14', status: 'skipped', name: '今後skip' })
    ]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway()
    );
    useCase.execute({ planId: 1, today, includeSkipped: true });

    expect(result!.upcoming).toHaveLength(1);
    expect(result!.upcoming[0].item.item_id).toBe(2);
    expect(result!.upcoming[0].item.status).toBe('skipped');
    expect(result!.overdue).toHaveLength(0);
    expect(result!.today).toHaveLength(0);
  });

  it('excludes overdue and upcoming skipped items when includeSkipped is false', () => {
    const response = scheduleWithItems([
      item({ item_id: 1, scheduled_date: '2026-06-08', status: 'skipped' }),
      item({ item_id: 2, scheduled_date: '2026-06-14', status: 'skipped' })
    ]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway()
    );
    useCase.execute({ planId: 1, today, includeSkipped: false });

    expect(result!.overdue).toHaveLength(0);
    expect(result!.today).toHaveLength(0);
    expect(result!.upcoming).toHaveLength(0);
  });

  it('shows completed items only when recorded today', () => {
    const response = scheduleWithItems([
      item({
        item_id: 1,
        scheduled_date: '2026-06-10',
        completed: true,
        work_records: [{ id: 9, actual_date: '2026-06-12', notes: null }],
        name: '潅水'
      }),
      item({
        item_id: 2,
        scheduled_date: '2026-06-10',
        completed: true,
        work_records: [{ id: 10, actual_date: '2026-06-10', notes: null }],
        name: '除草'
      })
    ]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway()
    );
    useCase.execute({ planId: 1, today });

    expect(result!.today).toHaveLength(1);
    expect(result!.today[0].item.name).toBe('潅水');
    expect(result!.today[0].recordedToday).toBe(true);
    expect(result!.overdue).toHaveLength(0);
  });

  it('excludes upcoming items beyond 7 days', () => {
    const response = scheduleWithItems([
      item({ item_id: 1, scheduled_date: '2026-06-20', name: '遠い作業' })
    ]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway()
    );
    useCase.execute({ planId: 1, today });

    expect(result!.upcoming).toHaveLength(0);
  });

  it('calls onError when gateway fails', () => {
    const onError = vi.fn();
    const gateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => throwError(() => new Error('fail')),
      regenerateTaskSchedule: () => of(undefined),
      deletePlan: () => of({} as never)
    };
    const outputPort: LoadWorkDayListOutputPort = {
      present: () => {},
      onError
    };

    const useCase = new LoadWorkDayListUseCase(outputPort, gateway, createWorkRecordGateway());
    useCase.execute({ planId: 1, today });

    expect(onError).toHaveBeenCalled();
  });

  it('returns recent ad hoc record for today when today list is empty', () => {
    const response = scheduleWithItems([]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway([
        adhocRecord({ id: 2, name: '規格選別', actual_date: today, created_at: '2026-06-12T10:00:00Z' }),
        adhocRecord({ id: 1, name: '古い記録', actual_date: '2026-06-10' })
      ])
    );
    useCase.execute({ planId: 1, today });

    expect(result!.today).toHaveLength(0);
    expect(result!.recentAdHocRecord).toEqual({ name: '規格選別', actualDate: today });
  });

  it('returns nextScheduled when overdue, today, and upcoming are all empty', () => {
    const response = scheduleWithItems([
      item({ item_id: 1, scheduled_date: '2026-06-20', name: '遠い収穫' })
    ]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway()
    );
    useCase.execute({ planId: 1, today });

    expect(result!.overdue).toHaveLength(0);
    expect(result!.today).toHaveLength(0);
    expect(result!.upcoming).toHaveLength(0);
    expect(result!.nextScheduled?.item.item_id).toBe(1);
    expect(result!.nextScheduled?.item.name).toBe('遠い収穫');
  });

  it('does not return nextScheduled when upcoming has items within 7 days', () => {
    const response = scheduleWithItems([
      item({ item_id: 1, scheduled_date: '2026-06-14', name: '今週の作業' }),
      item({ item_id: 2, scheduled_date: '2026-06-20', name: '遠い作業' })
    ]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway()
    );
    useCase.execute({ planId: 1, today });

    expect(result!.upcoming).toHaveLength(1);
    expect(result!.nextScheduled).toBeNull();
  });

  it('does not return recent ad hoc record when today has scheduled items', () => {
    const response = scheduleWithItems([
      item({ item_id: 1, scheduled_date: today, name: '防除' })
    ]);
    let result: LoadWorkDayListDataDto | null = null;
    const outputPort: LoadWorkDayListOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkDayListUseCase(
      outputPort,
      createGateway(response),
      createWorkRecordGateway([adhocRecord({ name: '規格選別', actual_date: today })])
    );
    useCase.execute({ planId: 1, today });

    expect(result!.today).toHaveLength(1);
    expect(result!.recentAdHocRecord).toBeNull();
  });
});

describe('findNextScheduled', () => {
  const today = '2026-06-12';
  const row = (
    overrides: Partial<TaskScheduleItem> & { item_id: number; scheduled_date: string | null }
  ) => ({
    item: item(overrides),
    fieldName: '第1圃場',
    cropName: 'トマト'
  });

  it('picks the nearest future scheduled item', () => {
    const result = findNextScheduled(
      [
        row({ item_id: 1, scheduled_date: '2026-06-20', name: '遠い' }),
        row({ item_id: 2, scheduled_date: '2026-06-15', name: '近い' })
      ],
      today,
      false
    );

    expect(result?.item.item_id).toBe(2);
    expect(result?.item.name).toBe('近い');
  });

  it('returns null when only past or today-dated items exist', () => {
    expect(
      findNextScheduled(
        [row({ item_id: 1, scheduled_date: '2026-06-10', name: '過去' })],
        today,
        false
      )
    ).toBeNull();
    expect(
      findNextScheduled(
        [row({ item_id: 2, scheduled_date: today, name: '今日' })],
        today,
        false
      )
    ).toBeNull();
  });

  it('excludes skipped items unless includeSkipped is true', () => {
    expect(
      findNextScheduled(
        [row({ item_id: 1, scheduled_date: '2026-06-15', status: 'skipped' })],
        today,
        false
      )
    ).toBeNull();
    expect(
      findNextScheduled(
        [row({ item_id: 1, scheduled_date: '2026-06-15', status: 'skipped' })],
        today,
        true
      )?.item.status
    ).toBe('skipped');
  });
});

describe('findTodayAdHocRecord', () => {
  it('picks the latest ad hoc record for today', () => {
    const records: WorkRecord[] = [
      {
        id: 1,
        cultivation_plan_id: 1,
        field_cultivation_id: null,
        task_schedule_item_id: null,
        agricultural_task_id: null,
        name: '古い',
        task_type: null,
        actual_date: '2026-06-12',
        amount: null,
        amount_unit: null,
        time_spent_minutes: null,
        notes: null,
        created_at: '2026-06-12T08:00:00Z',
        updated_at: '2026-06-12T08:00:00Z',
        task_schedule_item: null
      },
      {
        id: 2,
        cultivation_plan_id: 1,
        field_cultivation_id: null,
        task_schedule_item_id: null,
        agricultural_task_id: null,
        name: '最新',
        task_type: null,
        actual_date: '2026-06-12',
        amount: null,
        amount_unit: null,
        time_spent_minutes: null,
        notes: null,
        created_at: '2026-06-12T12:00:00Z',
        updated_at: '2026-06-12T12:00:00Z',
        task_schedule_item: null
      }
    ];

    expect(findTodayAdHocRecord(records, '2026-06-12')).toEqual({
      name: '最新',
      actualDate: '2026-06-12'
    });
  });
});
