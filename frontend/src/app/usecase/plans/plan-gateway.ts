import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVarianceLearningSnapshot } from '../../domain/plans/plan-variance-learning-snapshot';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { RegenerateTaskScheduleResponseDto } from './regenerate-task-schedule-response.dtos';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface TaskScheduleQueryParams {
  scope?: 'plan';
  field_cultivation_id?: number;
}

export interface PlanGateway {
  listPlans(): Observable<PlanSummary[]>;
  fetchPlan(planId: number): Observable<PlanSummary>;
  fetchPlanData(planId: number): Observable<CultivationPlanData>;
  getPublicPlanData(planId: number): Observable<CultivationPlanData>;
  getTaskSchedule(planId: number, params?: TaskScheduleQueryParams): Observable<TaskScheduleResponse>;
  getPlanVsActualSummary(planId: number): Observable<PlanVsActualSummary>;
  getVarianceLearning(planId: number): Observable<PlanVarianceLearningSnapshot>;
  importVarianceLearning(
    planId: number,
    sourcePlanId: number
  ): Observable<PlanVarianceLearningSnapshot>;
  regenerateTaskSchedule(planId: number): Observable<RegenerateTaskScheduleResponseDto>;
  deletePlan(planId: number): Observable<DeletionUndoResponse>;
}

export const PLAN_GATEWAY = new InjectionToken<PlanGateway>('PLAN_GATEWAY');
