import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiClientService } from '../../services/api-client.service';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { PlanGateway } from '../../usecase/plans/plan-gateway';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

@Injectable()
export class PlanApiGateway implements PlanGateway {
  constructor(private readonly apiClient: ApiClientService) {}

  listPlans(): Observable<PlanSummary[]> {
    return this.apiClient.get<PlanSummary[]>('/api/v1/plans');
  }

  fetchPlan(planId: number): Observable<PlanSummary> {
    return this.apiClient.get<PlanSummary>(`/api/v1/plans/${planId}`);
  }

  fetchPlanData(planId: number): Observable<CultivationPlanData> {
    return this.apiClient.get<CultivationPlanData>(`/api/v1/plans/cultivation_plans/${planId}/data`);
  }

  getPublicPlanData(planId: number): Observable<CultivationPlanData> {
    return this.apiClient.get<CultivationPlanData>(
      `/api/v1/public_plans/cultivation_plans/${planId}/data`
    );
  }

  getTaskSchedule(planId: number): Observable<TaskScheduleResponse> {
    return this.apiClient.get<TaskScheduleResponse>(`/api/v1/plans/${planId}/task_schedule`);
  }

  deletePlan(planId: number): Observable<DeletionUndoResponse> {
    return this.apiClient.delete<DeletionUndoResponse>(`/api/v1/plans/${planId}`);
  }
}
