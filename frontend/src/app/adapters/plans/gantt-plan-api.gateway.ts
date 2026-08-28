import { Injectable, Inject } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { Observable, of, throwError } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { CultivationPlanContextType } from '../../domain/plans/cultivation-plan-context-type';
import { LandingDemoLabels } from '../../domain/plans/landing-demo-i18n.keys';
import { buildGanttAdjustMove } from '../../domain/plans/gantt-chart-layout';
import {
  GanttPlanMutationCommandResult,
  ganttMutationCommandFailure,
  ganttMutationCommandSuccess
} from '../../domain/plans/gantt-plan-mutation';
import {
  GanttAddCropRequest,
  GanttAddFieldRequest
} from '../../usecase/plans/gantt-plan-mutation.dtos';
import { GanttPlanGateway } from '../../usecase/plans/gantt-plan-gateway';
import { ApiService } from '../../services/api.service';
import { buildGanttCultivationPlanEndpoint, ganttPrivatePlanDataPath, ganttPublicPlanDataPath } from './gantt-cultivation-plan-endpoints';
import { extractGanttPlanHttpErrorMessage } from './gantt-plan-http.helpers';
import type { WeatherRescheduleAdjustMove } from '../../domain/plans/weather-reschedule-proposal-preview';
import {
  GanttAddCropHttpResponse,
  GanttAddFieldHttpResponse,
  GanttAdjustPlanHttpResponse,
  GanttRemoveCultivationHttpResponse,
  GanttRemoveFieldHttpResponse
} from './gantt-plan-http.types';
import {
  PUBLIC_PLAN_SESSION_PORT,
  PublicPlanSessionPort
} from '../../usecase/public-plans/public-plan-session.port';
import { publicPlanSessionHeaders } from '../public-plans/public-plan-session-headers';

type ApiRequestOptions = {
  headers?: { [header: string]: string | string[] };
};

const DEMO_NOT_SUPPORTED = 'demo plan type is not supported by API gateway';

@Injectable()
export class GanttPlanApiGateway implements GanttPlanGateway {
  constructor(
    private readonly apiClient: ApiService,
    @Inject(PUBLIC_PLAN_SESSION_PORT) private readonly publicPlanSession: PublicPlanSessionPort
  ) {}

  private publicMutationOptions(planType: CultivationPlanContextType): ApiRequestOptions | undefined {
    if (planType !== 'public') {
      return undefined;
    }
    return {
      headers: publicPlanSessionHeaders(this.publicPlanSession.ensureSessionToken())
    };
  }

  loadPlanData(
    planType: CultivationPlanContextType,
    planId: number
  ): Observable<CultivationPlanData | null> {
    if (planType === 'demo') {
      return throwError(() => new Error(DEMO_NOT_SUPPORTED));
    }
    const request$ =
      planType === 'public'
        ? this.apiClient.get<CultivationPlanData>(ganttPublicPlanDataPath(planId))
        : this.apiClient.get<CultivationPlanData>(ganttPrivatePlanDataPath(planId));

    return request$.pipe(map((data) => (data?.data?.fields ? data : null)));
  }

  syncLandingDemoPlan(_labels: LandingDemoLabels): Observable<CultivationPlanData> {
    return throwError(() => new Error('demo-only'));
  }

  adjustPlanMoves(input: {
    planType: CultivationPlanContextType;
    planId: number;
    moves: WeatherRescheduleAdjustMove[];
  }): Observable<GanttPlanMutationCommandResult> {
    if (input.planType === 'demo') {
      return throwError(() => new Error(DEMO_NOT_SUPPORTED));
    }
    const endpoint = buildGanttCultivationPlanEndpoint(
      input.planType,
      input.planId,
      'adjust'
    );
    if (!endpoint) {
      return of(ganttMutationCommandFailure());
    }

    return this.apiClient.post<GanttAdjustPlanHttpResponse>(
      endpoint,
      { moves: input.moves },
      this.publicMutationOptions(input.planType) ?? {}
    ).pipe(
      map((response) =>
        response.success
          ? ganttMutationCommandSuccess()
          : ganttMutationCommandFailure(response.message)
      ),
      catchError((error: HttpErrorResponse) =>
        of(ganttMutationCommandFailure(extractGanttPlanHttpErrorMessage(error)))
      )
    );
  }

  adjustCultivationMove(input: {
    planType: CultivationPlanContextType;
    planId: number;
    cultivationId: number;
    toFieldId: number;
    newStartDate: Date;
  }): Observable<GanttPlanMutationCommandResult> {
    if (input.planType === 'demo') {
      return throwError(() => new Error(DEMO_NOT_SUPPORTED));
    }
    const endpoint = buildGanttCultivationPlanEndpoint(
      input.planType,
      input.planId,
      'adjust'
    );
    if (!endpoint) {
      return of(ganttMutationCommandFailure());
    }

    const moves = [buildGanttAdjustMove(input.cultivationId, input.toFieldId, input.newStartDate)];

    return this.apiClient.post<GanttAdjustPlanHttpResponse>(
      endpoint,
      { moves },
      this.publicMutationOptions(input.planType) ?? {}
    ).pipe(
      map((response) =>
        response.success
          ? ganttMutationCommandSuccess()
          : ganttMutationCommandFailure(response.message)
      ),
      catchError((error: HttpErrorResponse) =>
        of(ganttMutationCommandFailure(extractGanttPlanHttpErrorMessage(error)))
      )
    );
  }

  addCrop(
    planType: CultivationPlanContextType,
    planId: number,
    payload: GanttAddCropRequest
  ): Observable<GanttPlanMutationCommandResult> {
    if (planType === 'demo') {
      return throwError(() => new Error(DEMO_NOT_SUPPORTED));
    }
    const endpoint = buildGanttCultivationPlanEndpoint(planType, planId, 'add_crop');
    if (!endpoint) {
      return of(ganttMutationCommandFailure());
    }

    return this.apiClient.post<GanttAddCropHttpResponse>(
      endpoint,
      payload,
      this.publicMutationOptions(planType) ?? {}
    ).pipe(
      map((response) =>
        response.success
          ? ganttMutationCommandSuccess()
          : ganttMutationCommandFailure(response.message)
      ),
      catchError((error: HttpErrorResponse) =>
        of(ganttMutationCommandFailure(extractGanttPlanHttpErrorMessage(error)))
      )
    );
  }

  removeCultivation(
    planType: CultivationPlanContextType,
    planId: number,
    cultivationId: number
  ): Observable<GanttPlanMutationCommandResult> {
    if (planType === 'demo') {
      return throwError(() => new Error(DEMO_NOT_SUPPORTED));
    }
    const endpoint = buildGanttCultivationPlanEndpoint(planType, planId, 'adjust');
    if (!endpoint) {
      return of(ganttMutationCommandFailure());
    }

    return this.apiClient
      .post<GanttRemoveCultivationHttpResponse>(
        endpoint,
        {
          moves: [{ allocation_id: cultivationId, action: 'remove' }]
        },
        this.publicMutationOptions(planType) ?? {}
      )
      .pipe(
        map((response) =>
          response.success
            ? ganttMutationCommandSuccess()
            : ganttMutationCommandFailure(response.message)
        ),
        catchError((error: HttpErrorResponse) =>
          of(ganttMutationCommandFailure(extractGanttPlanHttpErrorMessage(error)))
        )
      );
  }

  addField(
    planType: CultivationPlanContextType,
    planId: number,
    payload: GanttAddFieldRequest
  ): Observable<GanttPlanMutationCommandResult> {
    if (planType === 'demo') {
      return throwError(() => new Error(DEMO_NOT_SUPPORTED));
    }
    const endpoint = buildGanttCultivationPlanEndpoint(planType, planId, 'add_field');
    if (!endpoint) {
      return of(ganttMutationCommandFailure());
    }

    return this.apiClient.post<GanttAddFieldHttpResponse>(
      endpoint,
      payload,
      this.publicMutationOptions(planType) ?? {}
    ).pipe(
      map((response) =>
        response.success
          ? ganttMutationCommandSuccess()
          : ganttMutationCommandFailure(response.message)
      ),
      catchError((error: HttpErrorResponse) =>
        of(ganttMutationCommandFailure(extractGanttPlanHttpErrorMessage(error)))
      )
    );
  }

  removeField(
    planType: CultivationPlanContextType,
    planId: number,
    fieldId: number
  ): Observable<GanttPlanMutationCommandResult> {
    if (planType === 'demo') {
      return throwError(() => new Error(DEMO_NOT_SUPPORTED));
    }
    const endpoint = buildGanttCultivationPlanEndpoint(
      planType,
      planId,
      'remove_field',
      fieldId
    );
    if (!endpoint) {
      return of(ganttMutationCommandFailure());
    }

    return this.apiClient.delete<GanttRemoveFieldHttpResponse>(
      endpoint,
      this.publicMutationOptions(planType) ?? {}
    ).pipe(
      map((response) =>
        response.success
          ? ganttMutationCommandSuccess()
          : ganttMutationCommandFailure(response.message)
      ),
      catchError((error: HttpErrorResponse) =>
        of(ganttMutationCommandFailure(extractGanttPlanHttpErrorMessage(error)))
      )
    );
  }
}
