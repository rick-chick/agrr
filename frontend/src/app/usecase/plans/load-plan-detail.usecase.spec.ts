import { of } from 'rxjs';
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
    const plan: PlanSummary = { id: 7, name: 'Plan 7', status: 'completed' };
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
      getTaskSchedule: () => of({ plan: {} as never, week: {} as never, milestones: [], fields: [], labels: {}, minimap: {} } as TaskScheduleResponse),
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
  });
});
