import { Injectable } from '@angular/core';
import { Observable, of } from 'rxjs';
import { map } from 'rxjs/operators';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import {
  CultivationPlanContextType,
  LANDING_DEMO_PLAN_ID
} from '../../domain/plans/cultivation-plan-context-type';
import { LandingDemoLabels } from '../../domain/plans/landing-demo-i18n.keys';
import {
  GanttPlanMutationCommandResult,
  ganttMutationCommandFailure
} from '../../domain/plans/gantt-plan-mutation';
import {
  GanttAddCropRequest,
  GanttAddFieldRequest
} from '../../usecase/plans/gantt-plan-mutation.dtos';
import { GanttPlanGateway } from '../../usecase/plans/gantt-plan-gateway';
import { DemoGanttPlanMemoryGateway } from './demo-gantt-plan-memory.gateway';

@Injectable()
export class DemoGanttPlanGateway implements GanttPlanGateway {
  constructor(private readonly demoStore: DemoGanttPlanMemoryGateway) {}

  loadPlanData(
    planType: CultivationPlanContextType,
    planId: number
  ): Observable<CultivationPlanData | null> {
    if (planType !== 'demo') {
      return of(null);
    }
    return this.demoStore.loadPlan(planId).pipe(map((data) => (data?.data?.fields ? data : null)));
  }

  syncLandingDemoPlan(labels: LandingDemoLabels): Observable<CultivationPlanData> {
    this.demoStore.initialize(labels);
    return this.demoStore.loadPlan(LANDING_DEMO_PLAN_ID).pipe(
      map((data) => {
        if (!data?.data?.fields) {
          throw new Error('landing demo plan data is empty');
        }
        return data;
      })
    );
  }

  adjustCultivationMove(input: {
    planType: CultivationPlanContextType;
    planId: number;
    cultivationId: number;
    toFieldId: number;
    newStartDate: Date;
  }): Observable<GanttPlanMutationCommandResult> {
    if (input.planType !== 'demo') {
      return of(ganttMutationCommandFailure());
    }
    return this.demoStore.adjustCultivationMove({
      planId: input.planId,
      cultivationId: input.cultivationId,
      toFieldId: input.toFieldId,
      newStartDate: input.newStartDate
    });
  }

  addCrop(
    planType: CultivationPlanContextType,
    planId: number,
    payload: GanttAddCropRequest
  ): Observable<GanttPlanMutationCommandResult> {
    if (planType !== 'demo') {
      return of(ganttMutationCommandFailure());
    }
    return this.demoStore.addCrop(planId, payload);
  }

  removeCultivation(
    planType: CultivationPlanContextType,
    planId: number,
    cultivationId: number
  ): Observable<GanttPlanMutationCommandResult> {
    if (planType !== 'demo') {
      return of(ganttMutationCommandFailure());
    }
    return this.demoStore.removeCultivation(planId, cultivationId);
  }

  addField(
    planType: CultivationPlanContextType,
    planId: number,
    payload: GanttAddFieldRequest
  ): Observable<GanttPlanMutationCommandResult> {
    if (planType !== 'demo') {
      return of(ganttMutationCommandFailure());
    }
    return this.demoStore.addField(planId, payload);
  }

  removeField(
    planType: CultivationPlanContextType,
    planId: number,
    fieldId: number
  ): Observable<GanttPlanMutationCommandResult> {
    if (planType !== 'demo') {
      return of(ganttMutationCommandFailure());
    }
    return this.demoStore.removeField(planId, fieldId);
  }
}
