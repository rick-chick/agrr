import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiClientService } from '../api-client.service';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';

@Injectable({ providedIn: 'root' })
export class PlanService {
  constructor(private readonly apiClient: ApiClientService) {}

  listPlans(): Observable<PlanSummary[]> {
    return this.apiClient.get<PlanSummary[]>('/api/v1/plans');
  }

  showPlan(planId: number): Observable<PlanSummary> {
    return this.apiClient.get<PlanSummary>(`/api/v1/plans/${planId}`);
  }

  getPlanData(planId: number): Observable<CultivationPlanData> {
    return this.apiClient.get<CultivationPlanData>(`/api/v1/plans/cultivation_plans/${planId}/data`);
  }

  getPublicPlanData(planId: number): Observable<CultivationPlanData> {
    return this.apiClient.get<CultivationPlanData>(`/api/v1/public_plans/cultivation_plans/${planId}/data`);
  }

  getTaskSchedule(planId: number): Observable<TaskScheduleResponse> {
    return this.apiClient.get<TaskScheduleResponse>(`/api/v1/plans/${planId}/task_schedule`);
  }

  addCrop(endpoint: string, payload: AddCropRequest): Observable<AddCropResponse> {
    return this.apiClient.post<AddCropResponse>(endpoint, payload);
  }

  removeCultivation(endpoint: string, payload: RemoveCultivationRequest): Observable<RemoveCultivationResponse> {
    return this.apiClient.post<RemoveCultivationResponse>(endpoint, payload);
  }

  addField(endpoint: string, payload: AddFieldRequest): Observable<AddFieldResponse> {
    return this.apiClient.post<AddFieldResponse>(endpoint, payload);
  }

  removeField(endpoint: string): Observable<RemoveFieldResponse> {
    return this.apiClient.delete<RemoveFieldResponse>(endpoint);
  }

  adjustPlan(endpoint: string, body: { moves: Array<{ allocation_id: number; action: string; to_field_id?: number; to_start_date?: string }> }): Observable<{ success: boolean; message?: string; cultivation_plan?: any }> {
    return this.apiClient.post<{ success: boolean; message?: string; cultivation_plan?: any }>(endpoint, body);
  }
}

type AddCropRequest = {
  crop_id: number;
  field_id?: number;
  start_date?: string;
};

type AddCropResponse = {
  success: boolean;
  message?: string;
  crop: {
    id: number;
    name: string;
  };
};

type RemoveCultivationRequest = {
  moves: Array<{
    allocation_id: number;
    action: string;
  }>;
};

type RemoveCultivationResponse = {
  success: boolean;
  message?: string;
};

type AddFieldRequest = {
  field_name: string;
  field_area: number;
  daily_fixed_cost?: number;
};

type AddFieldResponse = {
  success: boolean;
  message?: string;
  field: {
    id: number;
    field_id: number;
    name: string;
    area: number;
  };
  total_area: number;
};

type RemoveFieldResponse = {
  success: boolean;
  message?: string;
  field_id: number;
  total_area: number;
};
