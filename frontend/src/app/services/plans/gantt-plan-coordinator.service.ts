import { Injectable } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError, map, switchMap } from 'rxjs/operators';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { CultivationPlanContextType } from '../../domain/plans/cultivation-plan-context-type';
import { buildGanttAdjustMove } from '../../domain/plans/gantt-chart-layout';
import { GanttPlanMutationFailure } from '../../domain/plans/gantt-plan-mutation';
import {
  AddCropRequest,
  AddCropResponse,
  AddFieldRequest,
  AddFieldResponse,
  PlanService,
  RemoveCultivationResponse,
  RemoveFieldResponse
} from './plan.service';
import { DemoGanttPlanStore } from './demo-gantt-plan-store.service';

export type { GanttPlanMutationFailure };

export type GanttPlanMutationOutcome =
  | { status: 'success'; data: CultivationPlanData }
  | { status: 'failure'; failure: GanttPlanMutationFailure };

export function ganttMutationSuccess(data: CultivationPlanData): GanttPlanMutationOutcome {
  return { status: 'success', data };
}

export function ganttMutationFailure(failure: GanttPlanMutationFailure): GanttPlanMutationOutcome {
  return { status: 'failure', failure };
}

@Injectable({ providedIn: 'root' })
export class GanttPlanCoordinatorService {
  constructor(
    private readonly planService: PlanService,
    private readonly demoStore: DemoGanttPlanStore
  ) {}

  loadPlanData(
    planType: CultivationPlanContextType,
    planId: number
  ): Observable<CultivationPlanData | null> {
    if (planType === 'demo') {
      return this.demoStore.loadPlan(planId).pipe(map((data) => (data?.data?.fields ? data : null)));
    }
    const request$ =
      planType === 'public'
        ? this.planService.getPublicPlanData(planId)
        : this.planService.getPlanData(planId);

    return request$.pipe(
      map((data) => (data?.data?.fields ? data : null)),
      catchError(() => of(null))
    );
  }

  adjustCultivationMove(input: {
    planType: CultivationPlanContextType;
    planId: number;
    cultivationId: number;
    toFieldId: number;
    newStartDate: Date;
  }): Observable<GanttPlanMutationOutcome> {
    if (input.planType === 'demo') {
      return this.demoStore.adjustCultivationMove(input);
    }
    const endpoint = this.planService.buildCultivationPlanEndpoint(
      input.planType,
      input.planId,
      'adjust'
    );
    if (!endpoint) {
      return of(ganttMutationFailure({}));
    }

    const moves = [buildGanttAdjustMove(input.cultivationId, input.toFieldId, input.newStartDate)];

    return this.planService.adjustPlan(endpoint, { moves }).pipe(
      switchMap((response) => {
        if (!response.success) {
          return of(ganttMutationFailure({ message: response.message }));
        }
        return this.loadPlanData(input.planType, input.planId).pipe(
          map((data) =>
            data
              ? ganttMutationSuccess(data)
              : ganttMutationFailure({ refetchFailed: true })
          ),
          catchError(() => of(ganttMutationFailure({ refetchError: true })))
        );
      }),
      catchError((error: HttpErrorResponse) =>
        of(ganttMutationFailure({ message: extractHttpErrorMessage(error) }))
      )
    );
  }

  addCrop(
    planType: CultivationPlanContextType,
    planId: number,
    payload: AddCropRequest
  ): Observable<GanttPlanMutationOutcome> {
    if (planType === 'demo') {
      return this.demoStore.addCrop(planId, payload);
    }
    const endpoint = this.planService.buildCultivationPlanEndpoint(planType, planId, 'add_crop');
    if (!endpoint) {
      return of(ganttMutationFailure({}));
    }

    return this.planService.addCrop(endpoint, payload).pipe(
      switchMap((response: AddCropResponse) => {
        if (!response.success) {
          return of(ganttMutationFailure({ message: response.message }));
        }
        return this.afterMutationRefresh(planType, planId);
      }),
      catchError((error: HttpErrorResponse) =>
        of(ganttMutationFailure({ message: extractHttpErrorMessage(error) }))
      )
    );
  }

  removeCultivation(
    planType: CultivationPlanContextType,
    planId: number,
    cultivationId: number
  ): Observable<GanttPlanMutationOutcome> {
    if (planType === 'demo') {
      return this.demoStore.removeCultivation(planId, cultivationId);
    }
    const endpoint = this.planService.buildCultivationPlanEndpoint(planType, planId, 'adjust');
    if (!endpoint) {
      return of(ganttMutationFailure({}));
    }

    return this.planService
      .removeCultivation(endpoint, { moves: [{ allocation_id: cultivationId, action: 'remove' }] })
      .pipe(
        switchMap((response: RemoveCultivationResponse) =>
          response.success
            ? this.afterMutationRefresh(planType, planId)
            : of(ganttMutationFailure({ message: response.message }))
        ),
        catchError((error: HttpErrorResponse) =>
          of(ganttMutationFailure({ message: extractHttpErrorMessage(error) }))
        )
      );
  }

  addField(
    planType: CultivationPlanContextType,
    planId: number,
    payload: AddFieldRequest
  ): Observable<GanttPlanMutationOutcome> {
    if (planType === 'demo') {
      return this.demoStore.addField(planId, payload);
    }
    const endpoint = this.planService.buildCultivationPlanEndpoint(planType, planId, 'add_field');
    if (!endpoint) {
      return of(ganttMutationFailure({}));
    }

    return this.planService.addField(endpoint, payload).pipe(
      switchMap((response: AddFieldResponse) =>
        response.success
          ? this.afterMutationRefresh(planType, planId)
          : of(ganttMutationFailure({ message: response.message }))
      ),
      catchError((error: HttpErrorResponse) =>
        of(ganttMutationFailure({ message: extractHttpErrorMessage(error) }))
      )
    );
  }

  removeField(
    planType: CultivationPlanContextType,
    planId: number,
    fieldId: number
  ): Observable<GanttPlanMutationOutcome> {
    if (planType === 'demo') {
      return this.demoStore.removeField(planId, fieldId);
    }
    const endpoint = this.planService.buildCultivationPlanEndpoint(
      planType,
      planId,
      'remove_field',
      fieldId
    );
    if (!endpoint) {
      return of(ganttMutationFailure({}));
    }

    return this.planService.removeField(endpoint).pipe(
      switchMap((response: RemoveFieldResponse) =>
        response.success
          ? this.afterMutationRefresh(planType, planId)
          : of(ganttMutationFailure({ message: response.message }))
      ),
      catchError((error: HttpErrorResponse) =>
        of(ganttMutationFailure({ message: extractHttpErrorMessage(error) }))
      )
    );
  }

  private afterMutationRefresh(
    planType: CultivationPlanContextType,
    planId: number
  ): Observable<GanttPlanMutationOutcome> {
    return this.loadPlanData(planType, planId).pipe(
      map((data) =>
        data ? ganttMutationSuccess(data) : ganttMutationFailure({ refetchFailed: true })
      ),
      catchError(() => of(ganttMutationFailure({ refetchError: true })))
    );
  }
}

export function extractHttpErrorMessage(error: HttpErrorResponse): string | undefined {
  if (error?.error?.message) {
    return String(error.error.message);
  }
  return error.message;
}
