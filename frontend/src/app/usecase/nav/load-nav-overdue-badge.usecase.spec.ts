import { of, throwError } from 'rxjs';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { TaskScheduleItem } from '../../models/plans/task-schedule';
import { PlanGateway } from '../plans/plan-gateway';
import { WorkHubGateway } from '../work-hub/work-hub-gateway';
import { LoadNavOverdueBadgeOutputPort } from './load-nav-overdue-badge.output-port';
import { LoadNavOverdueBadgeUseCase } from './load-nav-overdue-badge.usecase';

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

describe('LoadNavOverdueBadgeUseCase', () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  const createPlanGateway = (overrides: Partial<PlanGateway> = {}): PlanGateway =>
    ({
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({ fields: [] } as never),
      getPlanVsActualSummary: () => of({ plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }),
      getWeatherRescheduleProposals: () => of([]),
      getVarianceLearning: () => of({ plan_id: 0, source_plan_id: 0, summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] } }),
      importVarianceLearning: () => of({ plan_id: 0, source_plan_id: 0, summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] } }),
      patchVarianceLearningProposalProgress: () => of({ plan_id: 0, proposal_application_progress: {} }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),

      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as never),
      ...overrides
    }) as PlanGateway;

  it('presents total overdue count across farms', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-06-12T12:00:00'));

    const workHubGateway: WorkHubGateway = {
      listHubFarms: () =>
        of([
          {
            farmId: 1,
            farmName: 'Farm 1',
            fieldCount: 1,
            totalArea: 10,
            hasValidFields: true,
            planId: 9,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            daysExceedanceCount: 0,
            thresholdExceededCount: 0
          },
          {
            farmId: 2,
            farmName: 'Farm 2',
            fieldCount: 1,
            totalArea: 10,
            hasValidFields: true,
            planId: 10,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            daysExceedanceCount: 0,
            thresholdExceededCount: 0
          }
        ])
    };

    const planGateway: PlanGateway = createPlanGateway({
      getTaskSchedule: (planId) =>
        of({
          fields: [
            {
              id: planId,
              name: '圃場',
              crop_name: '作物',
              area_sqm: 100,
              field_cultivation_id: 10,
              crop_id: 1,
              task_options: [],
              schedules: {
                general: [
                  item({
                    item_id: planId,
                    scheduled_date: planId === 9 ? '2026-06-08' : '2026-06-10'
                  })
                ],
                fertilizer: [],
                pest_control: [],
                unscheduled: []
              }
            }
          ]
        } as never),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),

      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as never)
    });

    const present = vi.fn();
    const outputPort: LoadNavOverdueBadgeOutputPort = { present };
    const useCase = new LoadNavOverdueBadgeUseCase(outputPort, workHubGateway, planGateway);

    useCase.execute();

    expect(present).toHaveBeenCalledWith({ overdueCount: 2 });
  });

  it('presents zero when hub farm loading fails', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () => throwError(() => new Error('network'))
    };
    const planGateway = createPlanGateway();
    const present = vi.fn();
    const outputPort: LoadNavOverdueBadgeOutputPort = { present };
    const useCase = new LoadNavOverdueBadgeUseCase(outputPort, workHubGateway, planGateway);

    useCase.execute();

    expect(present).toHaveBeenCalledWith({ overdueCount: 0 });
  });
});
