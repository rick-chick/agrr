import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../../services/api.service';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { PlanGateway, TaskScheduleQueryParams } from '../../usecase/plans/plan-gateway';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

@Injectable()
export class PlanApiGateway implements PlanGateway {
  constructor(private readonly apiClient: ApiService) {}

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

  getTaskSchedule(
    planId: number,
    params?: TaskScheduleQueryParams
  ): Observable<TaskScheduleResponse> {
    const query = new URLSearchParams();
    if (params?.scope) query.set('scope', params.scope);
    if (params?.field_cultivation_id != null) {
      query.set('field_cultivation_id', String(params.field_cultivation_id));
    }
    const qs = query.toString();
    const path = `/api/v1/plans/${planId}/task_schedule${qs ? `?${qs}` : ''}`;
    return this.apiClient.get<TaskScheduleResponse>(path);
  }

  regenerateTaskSchedule(planId: number): Observable<void> {
    return this.apiClient.post<void>(`/api/v1/plans/${planId}/task_schedule/regenerate`, {});
  }

  deletePlan(planId: number): Observable<DeletionUndoResponse> {
    return this.apiClient.delete<DeletionUndoResponse>(`/api/v1/plans/${planId}`);
  }
}
