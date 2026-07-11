import { of, throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import type { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { LoadCrossFarmScheduleUseCase } from './load-cross-farm-schedule.usecase';
import type { PlanGateway } from '../plans/plan-gateway';
import type { WorkHubGateway } from './work-hub-gateway';
import type { LoadCrossFarmScheduleOutputPort } from './load-cross-farm-schedule.output-port';

function mockSchedule(planName: string, fieldName: string): TaskScheduleResponse {
  return {
    plan: {
      id: 1,
      name: planName,
      status: 'completed',
      planning_start_date: '2026-01-01',
      planning_end_date: '2026-12-31',
      timeline_generated_at: null,
      timeline_generated_at_display: null,
      task_schedule_sync_state: 'ready',
      task_schedule_sync_error: null,
      task_schedule_sync_error_crop_id: null
    },
    week: { start_date: '2026-06-01', end_date: '2026-06-07', label: '', days: [] },
    milestones: [],
    fields: [
      {
        id: 1,
        name: fieldName,
        crop_name: 'Tomato',
        area_sqm: 100,
        field_cultivation_id: 101,
        crop_id: 1,
        task_options: [],
        schedules: {
          general: [
            {
              item_id: 1,
              name: 'Weeding',
              task_type: 'field_work',
              category: 'general',
              scheduled_date: '2026-06-10',
              stage_name: '',
              stage_order: 0,
              gdd_trigger: '',
              gdd_tolerance: '',
              priority: 1,
              source: 'agrr',
              weather_dependency: 'none',
              time_per_sqm: '',
              amount: '',
              amount_unit: '',
              status: 'planned',
              agricultural_task_id: 1,
              field_cultivation_id: 101,
              completed: false,
              work_records: [],
              details: {} as TaskScheduleResponse['fields'][number]['schedules']['general'][number]['details'],
              badge: {
                type: 'default',
                priority_level: '',
                status: 'planned',
                category: 'general'
              }
            }
          ],
          fertilizer: [],
          unscheduled: []
        }
      }
    ],
    labels: {},
    minimap: { start_date: '2026-06-01', end_date: '2026-06-14', weeks: [] }
  };
}

describe('LoadCrossFarmScheduleUseCase', () => {
  it('presents flattened rows across farms with plans', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () =>
        of([
          {
            farmId: 1,
            farmName: 'Farm A',
            fieldCount: 1,
            totalArea: 100,
            hasValidFields: true,
            planId: 10
          },
          {
            farmId: 2,
            farmName: 'Farm B',
            fieldCount: 1,
            totalArea: 80,
            hasValidFields: true,
            planId: 20
          }
        ])
    };
    const planGateway: PlanGateway = {
      listPlans: vi.fn(),
      fetchPlan: vi.fn(),
      fetchPlanData: vi.fn(),
      getPublicPlanData: vi.fn(),
      regenerateTaskSchedule: vi.fn(),
      deletePlan: vi.fn(),
      getTaskSchedule: vi.fn((planId: number) =>
        of(mockSchedule(planId === 10 ? 'Plan A' : 'Plan B', planId === 10 ? 'Field 1' : 'Field 2'))
      )
    };
    const beginScheduleLoad = vi.fn();
    const presentSchedule = vi.fn();
    const outputPort: LoadCrossFarmScheduleOutputPort = {
      beginScheduleLoad,
      presentSchedule,
      onScheduleError: vi.fn()
    };

    const useCase = new LoadCrossFarmScheduleUseCase(outputPort, workHubGateway, planGateway);
    useCase.execute();

    expect(beginScheduleLoad).toHaveBeenCalled();
    expect(presentSchedule).toHaveBeenCalledWith({
      rows: expect.arrayContaining([
        expect.objectContaining({ farmName: 'Farm A', fieldName: 'Field 1' }),
        expect.objectContaining({ farmName: 'Farm B', fieldName: 'Field 2' })
      ])
    });
  });

  it('presents empty rows when no farms have plans', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () =>
        of([
          {
            farmId: 1,
            farmName: 'Farm A',
            fieldCount: 1,
            totalArea: 100,
            hasValidFields: true,
            planId: null
          }
        ])
    };
    const planGateway = {
      getTaskSchedule: vi.fn()
    } as unknown as PlanGateway;
    const presentSchedule = vi.fn();
    const outputPort: LoadCrossFarmScheduleOutputPort = {
      beginScheduleLoad: vi.fn(),
      presentSchedule,
      onScheduleError: vi.fn()
    };

    const useCase = new LoadCrossFarmScheduleUseCase(outputPort, workHubGateway, planGateway);
    useCase.execute();

    expect(presentSchedule).toHaveBeenCalledWith({ rows: [] });
    expect(planGateway.getTaskSchedule).not.toHaveBeenCalled();
  });

  it('reports schedule errors', () => {
    const workHubGateway: WorkHubGateway = {
      listHubFarms: () => throwError(() => ({ status: 500 }))
    };
    const planGateway = {} as PlanGateway;
    const onScheduleError = vi.fn();
    const outputPort: LoadCrossFarmScheduleOutputPort = {
      beginScheduleLoad: vi.fn(),
      presentSchedule: vi.fn(),
      onScheduleError
    };

    const useCase = new LoadCrossFarmScheduleUseCase(outputPort, workHubGateway, planGateway);
    useCase.execute();

    expect(onScheduleError).toHaveBeenCalled();
  });
});
