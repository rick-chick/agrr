import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface PlanGateway {
  listPlans(): Observable<PlanSummary[]>;
  fetchPlan(planId: number): Observable<PlanSummary>;
  fetchPlanData(planId: number): Observable<CultivationPlanData>;
  getPublicPlanData(planId: number): Observable<CultivationPlanData>;
  getTaskSchedule(planId: number): Observable<TaskScheduleResponse>;
  deletePlan(planId: number): Observable<DeletionUndoResponse>;
}

export const PLAN_GATEWAY = new InjectionToken<PlanGateway>('PLAN_GATEWAY');
