import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { CultivationPlanContextType } from '../../domain/plans/cultivation-plan-context-type';
import { GanttPlanMutationCommandResult } from '../../domain/plans/gantt-plan-mutation';
import { LandingDemoLabels } from '../../domain/plans/landing-demo-i18n.keys';
import { GanttAddCropRequest, GanttAddFieldRequest } from './gantt-plan-mutation.dtos';

export interface GanttPlanGateway {
  loadPlanData(
    planType: CultivationPlanContextType,
    planId: number
  ): Observable<CultivationPlanData | null>;
  syncLandingDemoPlan(labels: LandingDemoLabels): Observable<CultivationPlanData>;
  adjustCultivationMove(input: {
    planType: CultivationPlanContextType;
    planId: number;
    cultivationId: number;
    toFieldId: number;
    newStartDate: Date;
  }): Observable<GanttPlanMutationCommandResult>;
  addCrop(
    planType: CultivationPlanContextType,
    planId: number,
    payload: GanttAddCropRequest
  ): Observable<GanttPlanMutationCommandResult>;
  removeCultivation(
    planType: CultivationPlanContextType,
    planId: number,
    cultivationId: number
  ): Observable<GanttPlanMutationCommandResult>;
  addField(
    planType: CultivationPlanContextType,
    planId: number,
    payload: GanttAddFieldRequest
  ): Observable<GanttPlanMutationCommandResult>;
  removeField(
    planType: CultivationPlanContextType,
    planId: number,
    fieldId: number
  ): Observable<GanttPlanMutationCommandResult>;
}

export const GANTT_PLAN_GATEWAY = new InjectionToken<GanttPlanGateway>('GANTT_PLAN_GATEWAY');
