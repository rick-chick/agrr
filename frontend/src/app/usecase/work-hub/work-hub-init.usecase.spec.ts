import { of, throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { TaskScheduleItem } from '../../models/plans/task-schedule';
import { WorkHubInitUseCase } from './work-hub-init.usecase';
import { WorkHubGateway } from './work-hub-gateway';
import { WorkHubInitOutputPort } from './work-hub-init.output-port';
import { EnsurePlanForFarmUseCase } from './ensure-plan-for-farm.usecase';
import { PlanGateway } from '../plans/plan-gateway';

const baseFarm = {
  fieldCount: 2,
  totalArea: 80,
  hasValidFields: true
};

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

describe('WorkHubInitUseCase', () => {
  const createPlanGateway = (overrides: Partial<PlanGateway> = {}): PlanGateway =>
    ({
      listPlans: () => of([]),
      fetchPlan: () => of({} as never),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({ fields: [] } as never),
      getPlanVsActualSummary: () => of({ plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }),
      getVarianceLearning: () => of({ plan_id: 0, source_plan_id: 0, summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] } }),
      importVarianceLearning: () => of({ plan_id: 0, source_plan_id: 0, summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] } }),
      patchVarianceLearningProposalProgress: () => of({ plan_id: 0, proposal_application_progress: {} }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),

      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as never),
      ...overrides
    }) as PlanGateway;

  it('presents farms with task counts when multiple farms exist', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-06-12T12:00:00'));

    const workHubGateway: WorkHubGateway = {
      listHubFarms: () =>
        of([
          {
            farmId: 1,
            farmName: 'Farm 1',
            ...baseFarm,
            planId: 9,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            thresholdExceededCount: 0
          },
          {
            farmId: 2,
            farmName: 'Farm 2',
            fieldCount: 1,
            totalArea: 40,
            hasValidFields: true,
            planId: 10,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            thresholdExceededCount: 0
          }
        ])
    };
    const present = vi.fn();
    const outputPort: WorkHubInitOutputPort = {
      present,
      onError: vi.fn(),
      beginEnsure: vi.fn()
    };
    const planGateway = createPlanGateway({
      getTaskSchedule: (planId: number) =>
        of({
          fields: [
            {
              id: 1,
              name: '第1圃場',
              crop_name: 'トマト',
              area_sqm: 100,
              field_cultivation_id: 10,
              crop_id: 1,
              task_options: [],
              schedules: {
                general:
                  planId === 9
                    ? [item({ item_id: 1, scheduled_date: '2026-06-08' })]
                    : [item({ item_id: 2, scheduled_date: '2026-06-12' })],
                fertilizer: [],
                pest_control: [],
                unscheduled: []
              }
            }
          ]
        } as never)
    });

    const useCase = new WorkHubInitUseCase(
      outputPort,
      workHubGateway,
      planGateway,
      { execute: vi.fn() } as unknown as EnsurePlanForFarmUseCase
    );
    useCase.execute();

    expect(present).toHaveBeenCalledWith({
      farms: [
        expect.objectContaining({
          farmId: 1,
          overdueCount: 1,
          todayCount: 0
        }),
        expect.objectContaining({
          farmId: 2,
          overdueCount: 0,
          todayCount: 1
        })
      ]
    });

    vi.useRealTimers();
  });

  it('presents zero counts when farms have no plans', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () =>
        of([
          {
            farmId: 1,
            farmName: 'Farm 1',
            ...baseFarm,
            planId: null,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            thresholdExceededCount: 0
          },
          {
            farmId: 2,
            farmName: 'Farm 2',
            fieldCount: 1,
            totalArea: 40,
            hasValidFields: true,
            planId: null,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            thresholdExceededCount: 0
          }
        ])
    };
    const present = vi.fn();
    const getTaskSchedule = vi.fn();
    const outputPort: WorkHubInitOutputPort = {
      present,
      onError: vi.fn(),
      beginEnsure: vi.fn()
    };

    const useCase = new WorkHubInitUseCase(
      outputPort,
      workHubGateway,
      createPlanGateway({ getTaskSchedule }),
      { execute: vi.fn() } as unknown as EnsurePlanForFarmUseCase
    );
    useCase.execute();

    expect(getTaskSchedule).not.toHaveBeenCalled();
    expect(present).toHaveBeenCalledWith({
      farms: [
        expect.objectContaining({ overdueCount: 0, todayCount: 0, unrecordedCount: 0, gddDelayCount: 0, thresholdExceededCount: 0 }),
        expect.objectContaining({ overdueCount: 0, todayCount: 0, unrecordedCount: 0, gddDelayCount: 0, thresholdExceededCount: 0 })
      ]
    });
  });

  it('auto-ensures when a single valid farm exists', () => {
    const farms = [
      {
        farmId: 5,
        farmName: 'Solo Farm',
        fieldCount: 1,
        totalArea: 50,
        hasValidFields: true,
        planId: 9,
        overdueCount: 0,
        todayCount: 0,
        unrecordedCount: 0,
        gddDelayCount: 0,
        thresholdExceededCount: 0
      }
    ];
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () => of(farms)
    };
    const beginEnsure = vi.fn();
    const present = vi.fn();
    const ensureExecute = vi.fn();
    const outputPort: WorkHubInitOutputPort = {
      present,
      onError: vi.fn(),
      beginEnsure
    };

    const useCase = new WorkHubInitUseCase(
      outputPort,
      workHubGateway,
      createPlanGateway(),
      { execute: ensureExecute } as unknown as EnsurePlanForFarmUseCase
    );
    useCase.execute();

    expect(present).toHaveBeenCalledWith({ farms });
    expect(beginEnsure).toHaveBeenCalled();
    expect(ensureExecute).toHaveBeenCalledWith({ farmId: 5, existingPlanId: 9 });
  });

  it('presents a single farm without valid fields', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () =>
        of([
          {
            farmId: 5,
            farmName: 'Solo Farm',
            fieldCount: 0,
            totalArea: 0,
            hasValidFields: false,
            planId: null,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            thresholdExceededCount: 0
          }
        ])
    };
    const present = vi.fn();
    const outputPort: WorkHubInitOutputPort = {
      present,
      onError: vi.fn(),
      beginEnsure: vi.fn()
    };

    const useCase = new WorkHubInitUseCase(
      outputPort,
      workHubGateway,
      createPlanGateway(),
      { execute: vi.fn() } as unknown as EnsurePlanForFarmUseCase
    );
    useCase.execute();

    expect(present).toHaveBeenCalledWith({
      farms: [
        expect.objectContaining({
          farmId: 5,
          hasValidFields: false,
          overdueCount: 0,
          todayCount: 0,
          gddDelayCount: 0,
          thresholdExceededCount: 0
        })
      ]
    });
  });

  it('presents farms with plan-core variance counts when multiple farms exist', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () =>
        of([
          {
            farmId: 1,
            farmName: 'Farm 1',
            ...baseFarm,
            planId: 9,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            thresholdExceededCount: 0
          },
          {
            farmId: 2,
            farmName: 'Farm 2',
            fieldCount: 1,
            totalArea: 40,
            hasValidFields: true,
            planId: 10,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            thresholdExceededCount: 0
          }
        ])
    };
    const present = vi.fn();
    const outputPort: WorkHubInitOutputPort = {
      present,
      onError: vi.fn(),
      beginEnsure: vi.fn()
    };
    const planGateway = createPlanGateway({
      getPlanVsActualSummary: (planId: number) =>
        of({
          plan_id: planId,
          unrecorded_count: 0,
          categories: [],
          top_variance_items: [],
          action_required_items:
            planId === 9
              ? [
                  {
                    item_id: 1,
                    field_cultivation_id: 10,
                    category: 'general',
                    name: '追肥',
                    scheduled_date: '2026-06-01',
                    actual_date: '2026-06-10',
                    delta_days: 5,
                    gdd_trigger: 100,
                    gdd_at_actual: 120,
                    gdd_delta: 15,
                    exceedance_kind: 'both'
                  },
                  {
                    item_id: 2,
                    field_cultivation_id: 10,
                    category: 'general',
                    name: '除草',
                    scheduled_date: '2026-06-02',
                    actual_date: '2026-06-08',
                    delta_days: 2,
                    gdd_trigger: 50,
                    gdd_at_actual: 65,
                    gdd_delta: 12,
                    exceedance_kind: 'days'
                  }
                ]
              : [
                  {
                    item_id: 3,
                    field_cultivation_id: 11,
                    category: 'fertilizer',
                    name: '施肥',
                    scheduled_date: '2026-06-03',
                    actual_date: '2026-06-10',
                    delta_days: 4,
                    gdd_trigger: 80,
                    gdd_at_actual: 95,
                    gdd_delta: 11,
                    exceedance_kind: 'gdd'
                  }
                ]
        })
    });

    const useCase = new WorkHubInitUseCase(
      outputPort,
      workHubGateway,
      planGateway,
      { execute: vi.fn() } as unknown as EnsurePlanForFarmUseCase
    );
    useCase.execute();

    expect(present).toHaveBeenCalledWith({
      farms: [
        expect.objectContaining({
          farmId: 1,
          gddDelayCount: 1,
          thresholdExceededCount: 2,
          unrecordedCount: 0
        }),
        expect.objectContaining({
          farmId: 2,
          gddDelayCount: 1,
          thresholdExceededCount: 1,
          unrecordedCount: 0
        })
      ]
    });
  });

  it('sorts farms by action-required count descending before presenting', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () =>
        of([
          {
            farmId: 1,
            farmName: 'Low',
            ...baseFarm,
            planId: 9,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            thresholdExceededCount: 0
          },
          {
            farmId: 2,
            farmName: 'High',
            fieldCount: 1,
            totalArea: 40,
            hasValidFields: true,
            planId: 10,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            thresholdExceededCount: 0
          },
          {
            farmId: 3,
            farmName: 'Mid',
            fieldCount: 1,
            totalArea: 40,
            hasValidFields: true,
            planId: 11,
            overdueCount: 0,
            todayCount: 0,
            unrecordedCount: 0,
            gddDelayCount: 0,
            thresholdExceededCount: 0
          }
        ])
    };
    const present = vi.fn();
    const outputPort: WorkHubInitOutputPort = {
      present,
      onError: vi.fn(),
      beginEnsure: vi.fn()
    };
    const planGateway = createPlanGateway({
      getPlanVsActualSummary: (planId: number) =>
        of({
          plan_id: planId,
          unrecorded_count: 0,
          categories: [],
          top_variance_items: [],
          action_required_items:
            planId === 9
              ? [
                  {
                    item_id: 1,
                    field_cultivation_id: 10,
                    category: 'general',
                    name: 'A',
                    scheduled_date: '2026-06-01',
                    actual_date: '2026-06-10',
                    delta_days: 5,
                    gdd_trigger: 100,
                    gdd_at_actual: 120,
                    gdd_delta: 15,
                    exceedance_kind: 'days'
                  }
                ]
              : planId === 10
                ? [
                    {
                      item_id: 2,
                      field_cultivation_id: 10,
                      category: 'general',
                      name: 'B',
                      scheduled_date: '2026-06-01',
                      actual_date: '2026-06-10',
                      delta_days: 5,
                      gdd_trigger: 100,
                      gdd_at_actual: 120,
                      gdd_delta: 15,
                      exceedance_kind: 'days'
                    },
                    {
                      item_id: 3,
                      field_cultivation_id: 10,
                      category: 'general',
                      name: 'C',
                      scheduled_date: '2026-06-02',
                      actual_date: '2026-06-08',
                      delta_days: 2,
                      gdd_trigger: 50,
                      gdd_at_actual: 65,
                      gdd_delta: 12,
                      exceedance_kind: 'days'
                    },
                    {
                      item_id: 4,
                      field_cultivation_id: 10,
                      category: 'general',
                      name: 'D',
                      scheduled_date: '2026-06-03',
                      actual_date: '2026-06-09',
                      delta_days: 3,
                      gdd_trigger: 50,
                      gdd_at_actual: 60,
                      gdd_delta: 10,
                      exceedance_kind: 'days'
                    }
                  ]
                : [
                    {
                      item_id: 5,
                      field_cultivation_id: 11,
                      category: 'fertilizer',
                      name: 'E',
                      scheduled_date: '2026-06-03',
                      actual_date: '2026-06-10',
                      delta_days: 4,
                      gdd_trigger: 80,
                      gdd_at_actual: 95,
                      gdd_delta: 11,
                      exceedance_kind: 'gdd'
                    },
                    {
                      item_id: 6,
                      field_cultivation_id: 11,
                      category: 'fertilizer',
                      name: 'F',
                      scheduled_date: '2026-06-04',
                      actual_date: '2026-06-11',
                      delta_days: 3,
                      gdd_trigger: 70,
                      gdd_at_actual: 85,
                      gdd_delta: 10,
                      exceedance_kind: 'days'
                    }
                  ]
        })
    });

    const useCase = new WorkHubInitUseCase(
      outputPort,
      workHubGateway,
      planGateway,
      { execute: vi.fn() } as unknown as EnsurePlanForFarmUseCase
    );
    useCase.execute();

    expect(present).toHaveBeenCalledWith({
      farms: [
        expect.objectContaining({ farmId: 2, thresholdExceededCount: 3 }),
        expect.objectContaining({ farmId: 3, thresholdExceededCount: 2 }),
        expect.objectContaining({ farmId: 1, thresholdExceededCount: 1 })
      ]
    });
  });

  it('forwards load errors to output port', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () => throwError(() => new Error('common.api_error.generic'))
    };
    const onError = vi.fn();
    const outputPort: WorkHubInitOutputPort = {
      present: vi.fn(),
      onError,
      beginEnsure: vi.fn()
    };

    const useCase = new WorkHubInitUseCase(
      outputPort,
      workHubGateway,
      createPlanGateway(),
      { execute: vi.fn() } as unknown as EnsurePlanForFarmUseCase
    );
    useCase.execute();

    expect(onError).toHaveBeenCalledWith({ message: 'common.api_error.generic' });
  });
});
