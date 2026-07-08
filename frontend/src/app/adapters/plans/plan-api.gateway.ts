import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../../services/api.service';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { PlanGateway, TaskScheduleQueryOptions } from '../../usecase/plans/plan-gateway';
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
    options?: TaskScheduleQueryOptions
  ): Observable<TaskScheduleResponse> {
    const params: { [key: string]: string } = {
      scope: options?.scope ?? 'plan'
    };
    if (options?.weekStart) {
      params['week_start'] = options.weekStart;
    }
    if (options?.fieldCultivationId != null) {
      params['field_cultivation_id'] = String(options.fieldCultivationId);
    }
    return this.apiClient.get<TaskScheduleResponse>(`/api/v1/plans/${planId}/task_schedule`, {
      params
    });
  }

  regenerateTaskSchedule(planId: number): Observable<void> {
    return this.apiClient.post<void>(`/api/v1/plans/${planId}/task_schedule/regenerate`, {});
  }

  deletePlan(planId: number): Observable<DeletionUndoResponse> {
    return this.apiClient.delete<DeletionUndoResponse>(`/api/v1/plans/${planId}`);
  }
}
