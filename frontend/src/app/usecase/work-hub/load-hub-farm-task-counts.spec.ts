import { of, firstValueFrom } from 'rxjs';
import { describe, expect, it } from 'vitest';
import { TaskScheduleItem } from '../../models/plans/task-schedule';
import { PlanGateway } from '../plans/plan-gateway';
import { loadHubFarmTaskCounts } from './load-hub-farm-task-counts';

function item(
  overrides: Partial<TaskScheduleItem> & { item_id: number; scheduled_date: string | null }
): TaskScheduleItem {
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
    details: {
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
    },
    badge: { type: 'task', priority_level: 'normal', status: 'planned', category: 'general' },
    ...overrides
  };
}

describe('loadHubFarmTaskCounts', () => {
  const today = '2026-06-12';

  it('returns per-farm overdue counts excluding skipped tasks', async () => {
    const planGateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: (planId) =>
        of({
          fields:
            planId === 9
              ? [
                  {
                    id: 1,
                    name: '第1圃場',
                    crop_name: 'トマト',
                    area_sqm: 100,
                    field_cultivation_id: 10,
                    crop_id: 1,
                    task_options: [],
                    schedules: {
                      general: [
                        item({ item_id: 1, scheduled_date: '2026-06-08' }),
                        item({ item_id: 2, scheduled_date: today, status: 'skipped' })
                      ],
                      fertilizer: [],
                      unscheduled: []
                    }
                  }
                ]
              : [
                  {
                    id: 2,
                    name: '第2圃場',
                    crop_name: 'キュウリ',
                    area_sqm: 80,
                    field_cultivation_id: 11,
                    crop_id: 2,
                    task_options: [],
                    schedules: {
                      general: [item({ item_id: 3, scheduled_date: '2026-06-10' })],
                      fertilizer: [],
                      unscheduled: []
                    }
                  }
                ]
        } as never),
      regenerateTaskSchedule: () => of(undefined),
      deletePlan: () => of({} as never)
    };

    const counts = await firstValueFrom(
      loadHubFarmTaskCounts(
        [
          { farmId: 1, planId: 9 },
          { farmId: 2, planId: 10 },
          { farmId: 3, planId: null }
        ],
        planGateway,
        today
      )
    );

    expect(counts.get(1)).toEqual({ overdueCount: 1, todayCount: 0 });
    expect(counts.get(2)).toEqual({ overdueCount: 1, todayCount: 0 });
    expect(counts.get(3)).toEqual({ overdueCount: 0, todayCount: 0 });
  });

  it('returns empty map when no farms have a plan', async () => {
    const planGateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({ fields: [] } as never),
      regenerateTaskSchedule: () => of(undefined),
      deletePlan: () => of({} as never)
    };

    const counts = await firstValueFrom(
      loadHubFarmTaskCounts(
        [
          { farmId: 1, planId: null },
          { farmId: 2, planId: null }
        ],
        planGateway,
        today
      )
    );

    expect(counts.size).toBe(0);
  });
});
