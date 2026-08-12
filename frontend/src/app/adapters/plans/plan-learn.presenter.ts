import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanLearnView, PlanLearnViewState } from '../../components/plans/plan-learn.view';
import { LoadPlanTaskScheduleOutputPort } from '../../usecase/plans/load-plan-task-schedule.output-port';
import { PlanTaskScheduleDataDto } from '../../usecase/plans/load-plan-task-schedule.dtos';
import { PlanVsActualSummaryDataDto } from '../../usecase/plans/load-plan-vs-actual-summary.output-port';
import { buildPlanVsActualPlanSummaryStats } from '../../domain/plans/build-plan-vs-actual-plan-summary';
import { flattenPlanTaskSchedule } from '../../domain/work-schedule/flatten-plan-task-schedule';
import { collectPlanTaskScheduleUnrecordedRows } from '../../domain/work-schedule/collect-plan-task-schedule-unrecorded-rows';
import { resolvePlanTaskScheduleDisplayStatus } from '../../domain/work-schedule/resolve-plan-task-schedule-display-status';
import type { PlanTaskScheduleRowView } from '../../components/plans/plan-task-schedule.view';
import type { CrossFarmScheduleRow } from '../../domain/work-schedule/cross-farm-schedule-row';
import { mapTaskScheduleResponseToDomain } from './map-task-schedule-response-to-domain';

const initialControl: PlanLearnViewState = {
  loading: true,
  error: null,
  planName: null,
  varianceLoading: true,
  varianceError: null,
  varianceSummary: null,
  varianceStats: null,
  varianceUnrecordedRows: []
};

@Injectable()
export class PlanLearnPresenter implements LoadPlanTaskScheduleOutputPort {
  private view: PlanLearnView | null = null;
  private varianceLoadGeneration = 0;

  setView(view: PlanLearnView): void {
    this.view = view;
  }

  beginVarianceLoad(): number {
    this.varianceLoadGeneration += 1;
    return this.varianceLoadGeneration;
  }

  present(dto: PlanTaskScheduleDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const snapshot = mapTaskScheduleResponseToDomain(dto.schedule);
    const rows = flattenPlanTaskSchedule(snapshot.plan, snapshot.fields);
    const varianceUnrecordedRows = enrichUnrecordedRows(collectPlanTaskScheduleUnrecordedRows(rows));
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      planName: dto.schedule.plan.name,
      varianceUnrecordedRows
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...initialControl,
      loading: false,
      error: dto.message,
      varianceLoading: false
    };
  }

  presentVarianceSummary(dto: PlanVsActualSummaryDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.loadGeneration !== this.varianceLoadGeneration) {
      return;
    }
    this.view.control = {
      ...this.view.control,
      varianceLoading: false,
      varianceError: null,
      varianceSummary: dto.summary,
      varianceStats: buildPlanVsActualPlanSummaryStats(dto.summary)
    };
  }

  onVarianceError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      varianceLoading: false,
      varianceError: dto.message,
      varianceSummary: null,
      varianceStats: null
    };
  }
}

function enrichUnrecordedRows(rows: ReadonlyArray<CrossFarmScheduleRow>): PlanTaskScheduleRowView[] {
  return rows.map(
    (row): PlanTaskScheduleRowView => ({
      ...row,
      displayStatus: resolvePlanTaskScheduleDisplayStatus(row.item)
    })
  );
}
