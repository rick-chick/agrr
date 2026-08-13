import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../../services/api.service';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import type { PlanVarianceLearningSnapshot } from '../../domain/plans/plan-variance-learning-snapshot';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { PlanGateway, TaskScheduleQueryParams } from '../../usecase/plans/plan-gateway';
import { RegenerateTaskScheduleResponseDto } from '../../usecase/plans/regenerate-task-schedule-response.dtos';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import {
  TaskScheduleItemCreateRequest,
  TaskScheduleItemUpdateRequest
} from '../../usecase/plans/plan-gateway';
import { TaskScheduleItemMutationResponse } from '../../usecase/plans/task-schedule-item-mutation.dtos';

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

  getPlanVsActualSummary(planId: number): Observable<PlanVsActualSummary> {
    return this.apiClient.get<PlanVsActualSummary>(
      `/api/v1/plans/${planId}/plan_vs_actual/summary`
    );
  }

  getVarianceLearning(planId: number): Observable<PlanVarianceLearningSnapshot> {
    return this.apiClient.get<PlanVarianceLearningSnapshot>(
      `/api/v1/plans/${planId}/variance_learning`
    );
  }

  importVarianceLearning(
    planId: number,
    sourcePlanId: number
  ): Observable<PlanVarianceLearningSnapshot> {
    return this.apiClient.post<PlanVarianceLearningSnapshot>(
      `/api/v1/plans/${planId}/variance_learning`,
      { source_plan_id: sourcePlanId }
    );
  }

  patchVarianceLearningProposalProgress(
    planId: number,
    proposalApplicationProgress: Record<string, string>
  ): Observable<PlanVarianceLearningSnapshot> {
    return this.apiClient.patch<PlanVarianceLearningSnapshot>(
      `/api/v1/plans/${planId}/variance_learning`,
      { proposal_application_progress: proposalApplicationProgress }
    );
  }

  regenerateTaskSchedule(planId: number): Observable<RegenerateTaskScheduleResponseDto> {
    return this.apiClient.post<RegenerateTaskScheduleResponseDto>(
      `/api/v1/plans/${planId}/task_schedule/regenerate`,
      {}
    );
  }

  createTaskScheduleItem(
    planId: number,
    body: TaskScheduleItemCreateRequest
  ): Observable<TaskScheduleItemMutationResponse> {
    return this.apiClient.post<TaskScheduleItemMutationResponse>(
      `/api/v1/plans/${planId}/task_schedule/items`,
      { task_schedule_item: body }
    );
  }

  updateTaskScheduleItem(
    planId: number,
    itemId: number,
    body: TaskScheduleItemUpdateRequest
  ): Observable<TaskScheduleItemMutationResponse> {
    return this.apiClient.patch<TaskScheduleItemMutationResponse>(
      `/api/v1/plans/${planId}/task_schedule/items/${itemId}`,
      { task_schedule_item: body }
    );
  }

  deletePlan(planId: number): Observable<DeletionUndoResponse> {
    return this.apiClient.delete<DeletionUndoResponse>(`/api/v1/plans/${planId}`);
  }
}
