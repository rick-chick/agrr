import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanLearnView, PlanLearnViewState } from '../../components/plans/plan-learn.view';
import { LoadPlanTaskScheduleOutputPort } from '../../usecase/plans/load-plan-task-schedule.output-port';
import { PlanTaskScheduleDataDto } from '../../usecase/plans/load-plan-task-schedule.dtos';
import { PlanVsActualSummaryDataDto } from '../../usecase/plans/load-plan-vs-actual-summary.output-port';
import {
  LoadBlueprintTimingAdjustmentProposalsOutputDto,
  LoadBlueprintTimingAdjustmentProposalsOutputPort
} from '../../usecase/plans/load-blueprint-timing-adjustment-proposals.output-port';
import {
  LoadStageGddCalibrationProposalsDataDto,
  LoadStageGddCalibrationProposalsOutputPort
} from '../../usecase/plans/load-stage-gdd-calibration-proposals.output-port';
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
  varianceUnrecordedRows: [],
  blueprintTimingLoading: false,
  blueprintTimingProposals: [],
  stageGddProposalsLoading: false,
  stageGddProposals: [],
  farmId: null,
  learningSnapshot: null,
  learningSnapshotLoading: true,
  carryoverSourcePlans: [],
  selectedSourcePlanId: null,
  carryoverPreviewLoading: false,
  carryoverPreviewError: null,
  carryoverPreview: null,
  carryoverImporting: false,
  carryoverImportError: null
};

@Injectable()
export class PlanLearnPresenter
  implements
    LoadPlanTaskScheduleOutputPort,
    LoadBlueprintTimingAdjustmentProposalsOutputPort,
    LoadStageGddCalibrationProposalsOutputPort
{
  private view: PlanLearnView | null = null;
  private varianceLoadGeneration = 0;
  private blueprintTimingProposalsLoadGeneration = 0;
  private stageGddProposalsLoadGeneration = 0;

  setView(view: PlanLearnView): void {
    this.view = view;
  }

  beginVarianceLoad(): number {
    this.varianceLoadGeneration += 1;
    this.blueprintTimingProposalsLoadGeneration += 1;
    this.stageGddProposalsLoadGeneration += 1;
    return this.varianceLoadGeneration;
  }

  beginBlueprintTimingProposalsLoad(): number {
    this.blueprintTimingProposalsLoadGeneration += 1;
    return this.blueprintTimingProposalsLoadGeneration;
  }

  beginStageGddProposalsLoad(): number {
    this.stageGddProposalsLoadGeneration += 1;
    return this.stageGddProposalsLoadGeneration;
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
      varianceStats: buildPlanVsActualPlanSummaryStats(dto.summary),
      blueprintTimingLoading:
        (dto.summary.blueprint_timing_adjustment_proposals?.length ?? 0) > 0,
      blueprintTimingProposals: [],
      stageGddProposalsLoading:
        (dto.summary.stage_gdd_calibration_proposals?.length ?? 0) > 0,
      stageGddProposals: []
    };
  }

  presentBlueprintTimingProposals(dto: LoadBlueprintTimingAdjustmentProposalsOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.loadGeneration !== this.blueprintTimingProposalsLoadGeneration) {
      return;
    }
    this.view.control = {
      ...this.view.control,
      blueprintTimingLoading: false,
      blueprintTimingProposals: dto.proposals
    };
  }

  presentStageGddProposals(dto: LoadStageGddCalibrationProposalsDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.loadGeneration !== this.stageGddProposalsLoadGeneration) {
      return;
    }
    this.view.control = {
      ...this.view.control,
      stageGddProposalsLoading: false,
      stageGddProposals: dto.proposals
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
