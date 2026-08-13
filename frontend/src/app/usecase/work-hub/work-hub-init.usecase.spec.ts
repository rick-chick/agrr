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
            todayCount: 0
          },
          {
            farmId: 2,
            farmName: 'Farm 2',
            fieldCount: 1,
            totalArea: 40,
            hasValidFields: true,
            planId: 10,
            overdueCount: 0,
            todayCount: 0
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
            todayCount: 0
          },
          {
            farmId: 2,
            farmName: 'Farm 2',
            fieldCount: 1,
            totalArea: 40,
            hasValidFields: true,
            planId: null,
            overdueCount: 0,
            todayCount: 0
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
        expect.objectContaining({ overdueCount: 0, todayCount: 0 }),
        expect.objectContaining({ overdueCount: 0, todayCount: 0 })
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
        todayCount: 0
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
            todayCount: 0
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
          todayCount: 0
        })
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
