import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { LoadWorkDayListUseCase } from './load-work-day-list.usecase';
import { PlanGateway } from './plan-gateway';
import { LoadWorkDayListOutputPort } from './load-work-day-list.output-port';
import { LoadWorkDayListDataDto } from './load-work-day-list.dtos';
import { TaskScheduleItem, TaskScheduleResponse } from '../../models/plans/task-schedule';

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
      timeline_generated_at_display: '2026-06-01'
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
    minimap: {}
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
      deletePlan: () => of({} as never)
    }) as PlanGateway;

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

    const useCase = new LoadWorkDayListUseCase(outputPort, createGateway(response));
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

    const useCase = new LoadWorkDayListUseCase(outputPort, createGateway(response));
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

    const useCase = new LoadWorkDayListUseCase(outputPort, createGateway(response));
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

    const useCase = new LoadWorkDayListUseCase(outputPort, createGateway(response));
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

    const useCase = new LoadWorkDayListUseCase(outputPort, createGateway(response));
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

    const useCase = new LoadWorkDayListUseCase(outputPort, createGateway(response));
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

    const useCase = new LoadWorkDayListUseCase(outputPort, createGateway(response));
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

    const useCase = new LoadWorkDayListUseCase(outputPort, createGateway(response));
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
      deletePlan: () => of({} as never)
    };
    const outputPort: LoadWorkDayListOutputPort = {
      present: () => {},
      onError
    };

    const useCase = new LoadWorkDayListUseCase(outputPort, gateway);
    useCase.execute({ planId: 1, today });

    expect(onError).toHaveBeenCalled();
  });
});
