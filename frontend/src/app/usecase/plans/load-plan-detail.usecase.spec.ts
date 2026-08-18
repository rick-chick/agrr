import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { vi } from 'vitest';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { LoadPlanDetailUseCase } from './load-plan-detail.usecase';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import { PlanGateway } from './plan-gateway';
import { LoadPlanDetailOutputPort } from './load-plan-detail.output-port';
import { PlanDetailDataDto } from './load-plan-detail.dtos';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

describe('LoadPlanDetailUseCase', () => {
  it('calls outputPort.present with plan and planData from gateway', () => {
    const plan: PlanSummary = { id: 7, name: 'Plan 7', status: 'completed', farm_id: 1 };
    const planData: CultivationPlanData = {
      success: true,
      data: {
        id: 7,
        plan_year: 2024,
        plan_name: 'Plan 7',
        status: 'completed',
        total_area: 100,
        planning_start_date: '2024-01-01',
        planning_end_date: '2024-12-31',
        fields: [],
        crops: [],
        cultivations: []
      },
      total_profit: 0,
      total_revenue: 0,
      total_cost: 0
    };

    const gateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of(plan),
      fetchPlanData: () => of(planData),
      getPublicPlanData: () => of(planData),
      getTaskSchedule: () => of({ plan: {} as never, week: {} as never, milestones: [], fields: [], labels: {}, minimap: { start_date: '', end_date: '', weeks: [] } } as TaskScheduleResponse),
      getPlanVsActualSummary: () => of({ plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }),
      getWeatherRescheduleProposals: () => of([]),
      previewWeatherRescheduleProposal: () => of({} as never),
      getVarianceLearning: () => of({ plan_id: 0, source_plan_id: 0, summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] } }),
      importVarianceLearning: () => of({ plan_id: 0, source_plan_id: 0, summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] } }),
      patchVarianceLearningProposalProgress: () => of({ plan_id: 0, proposal_application_progress: {} }),
      reoptimizeVarianceLearning: () => of({ success: true, plan_id: 0, optimization_enqueued: true }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),

      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as DeletionUndoResponse)
    };

    let receivedDto: PlanDetailDataDto | null = null;
    const outputPort: LoadPlanDetailOutputPort = {
      present: (dto) => {
        receivedDto = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadPlanDetailUseCase(outputPort, gateway);
    useCase.execute({ planId: 7 });

    expect(receivedDto).not.toBeNull();
    expect(receivedDto!.plan).toEqual(plan);
    expect(receivedDto!.planData).toEqual(planData);
    expect(receivedDto!.varianceActionItemsOnGantt).toEqual([]);
    expect(receivedDto!.weatherProposals).toEqual([]);
  });

  it('filters variance action items to cultivations on the gantt', () => {
    const plan: PlanSummary = { id: 7, name: 'Plan 7', status: 'completed', farm_id: 1 };
    const planData: CultivationPlanData = {
      success: true,
      data: {
        id: 7,
        plan_year: 2024,
        plan_name: 'Plan 7',
        status: 'completed',
        total_area: 100,
        planning_start_date: '2024-01-01',
        planning_end_date: '2024-12-31',
        fields: [],
        crops: [],
        cultivations: [
          {
            id: 100,
            field_id: 1,
            field_name: 'F1',
            crop_id: 1,
            crop_name: 'Tomato',
            area: 50,
            start_date: '2024-04-01',
            completion_date: '2024-10-01',
            cultivation_days: 180,
            estimated_cost: 0,
            revenue: 0,
            profit: 0,
            status: 'completed'
          }
        ]
      },
      total_profit: 0,
      total_revenue: 0,
      total_cost: 0
    };

    const gateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of(plan),
      fetchPlanData: () => of(planData),
      getPublicPlanData: () => of(planData),
      getTaskSchedule: () =>
        of({
          plan: {} as never,
          week: {} as never,
          milestones: [],
          fields: [],
          labels: {},
          minimap: { start_date: '', end_date: '', weeks: [] }
        } as TaskScheduleResponse),
      getPlanVsActualSummary: () =>
        of({
          plan_id: 7,
          unrecorded_count: 0,
          categories: [],
          top_variance_items: [],
          action_required_items: [
            {
              item_id: 11,
              field_cultivation_id: 100,
              category: 'general',
              name: 'Weed',
              scheduled_date: '2026-06-01',
              actual_date: '2026-06-08',
              delta_days: 7,
              gdd_trigger: 100,
              gdd_at_actual: 110,
              gdd_delta: 10,
              exceedance_kind: 'days'
            },
            {
              item_id: 12,
              field_cultivation_id: 999,
              category: 'general',
              name: 'Other',
              scheduled_date: '2026-06-01',
              actual_date: '2026-06-08',
              delta_days: 7,
              gdd_trigger: 100,
              gdd_at_actual: 110,
              gdd_delta: 10,
              exceedance_kind: 'days'
            }
          ]
        }),
      getWeatherRescheduleProposals: () => of([]),
      previewWeatherRescheduleProposal: () => of({} as never),
      getVarianceLearning: () => of({ plan_id: 0, source_plan_id: 0, summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] } }),
      importVarianceLearning: () => of({ plan_id: 0, source_plan_id: 0, summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] } }),
      patchVarianceLearningProposalProgress: () => of({ plan_id: 0, proposal_application_progress: {} }),
      reoptimizeVarianceLearning: () => of({ success: true, plan_id: 0, optimization_enqueued: true }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),

      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as DeletionUndoResponse)
    };

    let receivedDto: PlanDetailDataDto | null = null;
    const outputPort: LoadPlanDetailOutputPort = {
      present: (dto) => {
        receivedDto = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadPlanDetailUseCase(outputPort, gateway);
    useCase.execute({ planId: 7 });

    expect(receivedDto?.varianceActionItemsOnGantt).toHaveLength(1);
    expect(receivedDto?.varianceActionItemsOnGantt[0].field_cultivation_id).toBe(100);
  });

  it('calls onError with i18n key when fetchPlan fails with 401', () => {
    const planData: CultivationPlanData = {
      success: true,
      data: {
        id: 7,
        plan_year: 2024,
        plan_name: 'Plan 7',
        status: 'completed',
        total_area: 100,
        planning_start_date: '2024-01-01',
        planning_end_date: '2024-12-31',
        fields: [],
        crops: [],
        cultivations: []
      },
      total_profit: 0,
      total_revenue: 0,
      total_cost: 0
    };

    const gateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () =>
        throwError(() => new HttpErrorResponse({ status: 401, statusText: 'Unauthorized' })),
      fetchPlanData: () => of(planData),
      getPublicPlanData: () => of(planData),
      getTaskSchedule: () =>
        of({
          plan: {} as never,
          week: {} as never,
          milestones: [],
          fields: [],
          labels: {},
          minimap: { start_date: '', end_date: '', weeks: [] }
        } as TaskScheduleResponse),
      getPlanVsActualSummary: () => of({ plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }),
      getWeatherRescheduleProposals: () => of([]),
      previewWeatherRescheduleProposal: () => of({} as never),
      getVarianceLearning: () => of({ plan_id: 0, source_plan_id: 0, summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] } }),
      importVarianceLearning: () => of({ plan_id: 0, source_plan_id: 0, summary: { plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] } }),
      patchVarianceLearningProposalProgress: () => of({ plan_id: 0, proposal_application_progress: {} }),
      reoptimizeVarianceLearning: () => of({ success: true, plan_id: 0, optimization_enqueued: true }),
      regenerateTaskSchedule: () => of(undefined),
      createTaskScheduleItem: () => of({} as never),

      updateTaskScheduleItem: () => of({} as never),
      deletePlan: () => of({} as DeletionUndoResponse)
    };

    const onError = vi.fn();
    const outputPort: LoadPlanDetailOutputPort = {
      present: () => {},
      onError
    };

    const useCase = new LoadPlanDetailUseCase(outputPort, gateway);
    useCase.execute({ planId: 7 });

    expect(onError).toHaveBeenCalledWith({ message: 'common.api_error.unauthorized' });
  });
});
