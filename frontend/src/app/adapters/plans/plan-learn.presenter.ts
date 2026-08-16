import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanLearnView, PlanLearnViewState } from '../../components/plans/plan-learn.view';
import { LoadPlanTaskScheduleOutputPort } from '../../usecase/plans/load-plan-task-schedule.output-port';
import { PlanTaskScheduleDataDto } from '../../usecase/plans/load-plan-task-schedule.dtos';
import { PlanVsActualSummaryDataDto } from '../../usecase/plans/load-plan-vs-actual-summary.output-port';
import {
  LoadBlueprintAmountAdjustmentProposalsOutputDto,
  LoadBlueprintAmountAdjustmentProposalsOutputPort
} from '../../usecase/plans/load-blueprint-amount-adjustment-proposals.output-port';
import {
  LoadBlueprintTimingAdjustmentProposalsOutputDto,
  LoadBlueprintTimingAdjustmentProposalsOutputPort
} from '../../usecase/plans/load-blueprint-timing-adjustment-proposals.output-port';
import {
  LoadStageGddCalibrationProposalsDataDto,
  LoadStageGddCalibrationProposalsOutputPort
} from '../../usecase/plans/load-stage-gdd-calibration-proposals.output-port';
import { buildPlanVsActualPlanSummaryStats } from '../../domain/plans/build-plan-vs-actual-plan-summary';
import { collectLearnProposalRawSources } from '../../domain/plans/collect-learn-proposal-raw-sources';
import { extractAmountLearnProposalEvidenceSources } from '../../domain/plans/extract-amount-learn-proposal-evidence-sources';
import { extractLearnProposalEvidenceSources } from '../../domain/plans/extract-learn-proposal-evidence-sources';
import {
  blueprintAmountProposalEvidenceKey,
  buildBlueprintAmountProposalEvidence,
  buildBlueprintTimingProposalEvidence,
  buildLearnProposalEvidenceMap,
  buildStageGddProposalEvidence,
  type LearnProposalEvidenceSource
} from '../../domain/plans/learn-proposal-evidence';
import type { PlanFieldSchedule } from '../../domain/work-schedule/plan-schedule-snapshot';
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
  blueprintTimingEvidenceByKey: {},
  blueprintAmountLoading: false,
  blueprintAmountProposals: [],
  blueprintAmountEvidenceByKey: {},
  stageGddProposalsLoading: false,
  stageGddProposals: [],
  stageGddEvidenceByKey: {},
  learningSnapshot: null,
  carryoverSourcePlans: [],
  selectedSourcePlanId: null,
  carryoverPreviewLoading: false,
  carryoverPreviewError: null,
  carryoverPreview: null,
  carryoverImporting: false,
  carryoverImportError: null,
  postMasterPayload: null
};

@Injectable()
export class PlanLearnPresenter
  implements
    LoadPlanTaskScheduleOutputPort,
    LoadBlueprintTimingAdjustmentProposalsOutputPort,
    LoadBlueprintAmountAdjustmentProposalsOutputPort,
    LoadStageGddCalibrationProposalsOutputPort
{
  private view: PlanLearnView | null = null;
  private varianceLoadGeneration = 0;
  private blueprintTimingProposalsLoadGeneration = 0;
  private blueprintAmountProposalsLoadGeneration = 0;
  private stageGddProposalsLoadGeneration = 0;
  private scheduleFields: PlanFieldSchedule[] = [];
  private evidenceSources: LearnProposalEvidenceSource[] = [];

  setView(view: PlanLearnView): void {
    this.view = view;
  }

  getLearningSnapshot(): PlanLearnViewState['learningSnapshot'] {
    return this.view?.control.learningSnapshot ?? null;
  }

  beginVarianceLoad(): number {
    this.varianceLoadGeneration += 1;
    this.blueprintTimingProposalsLoadGeneration += 1;
    this.blueprintAmountProposalsLoadGeneration += 1;
    this.stageGddProposalsLoadGeneration += 1;
    return this.varianceLoadGeneration;
  }

  beginBlueprintTimingProposalsLoad(): number {
    this.blueprintTimingProposalsLoadGeneration += 1;
    return this.blueprintTimingProposalsLoadGeneration;
  }

  beginBlueprintAmountProposalsLoad(): number {
    this.blueprintAmountProposalsLoadGeneration += 1;
    return this.blueprintAmountProposalsLoadGeneration;
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
    this.scheduleFields = [...snapshot.fields];
    this.rebuildEvidenceSources(this.view.control.varianceSummary);
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      planName: dto.schedule.plan.name,
      varianceUnrecordedRows,
      ...this.buildProposalEvidenceState()
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
    const proposalSources = collectLearnProposalRawSources(
      dto.summary,
      this.getLearningSnapshot()
    );
    this.rebuildEvidenceSources(dto.summary);
    this.view.control = {
      ...this.view.control,
      varianceLoading: false,
      varianceError: null,
      varianceSummary: dto.summary,
      varianceStats: buildPlanVsActualPlanSummaryStats(dto.summary),
      blueprintTimingLoading: proposalSources.blueprintTimingAdjustmentProposals.length > 0,
      blueprintTimingProposals: [],
      blueprintAmountLoading: proposalSources.blueprintAmountAdjustmentProposals.length > 0,
      blueprintAmountProposals: [],
      stageGddProposalsLoading: proposalSources.stageGddCalibrationProposals.length > 0,
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
      blueprintTimingProposals: dto.proposals,
      ...this.buildProposalEvidenceState({ blueprintTimingProposals: dto.proposals })
    };
  }

  presentBlueprintAmountProposals(dto: LoadBlueprintAmountAdjustmentProposalsOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.loadGeneration !== this.blueprintAmountProposalsLoadGeneration) {
      return;
    }
    this.view.control = {
      ...this.view.control,
      blueprintAmountLoading: false,
      blueprintAmountProposals: dto.proposals,
      ...this.buildProposalEvidenceState({ blueprintAmountProposals: dto.proposals })
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
      stageGddProposals: dto.proposals,
      ...this.buildProposalEvidenceState({ stageGddProposals: dto.proposals })
    };
  }

  private rebuildEvidenceSources(
    varianceSummary: PlanLearnViewState['varianceSummary']
  ): void {
    const scheduleSources = extractLearnProposalEvidenceSources(this.scheduleFields);
    const amountSources = extractAmountLearnProposalEvidenceSources(
      varianceSummary,
      this.scheduleFields
    );
    this.evidenceSources = [...scheduleSources, ...amountSources];
  }

  private buildProposalEvidenceState(
    overrides: {
      blueprintTimingProposals?: PlanLearnViewState['blueprintTimingProposals'];
      blueprintAmountProposals?: PlanLearnViewState['blueprintAmountProposals'];
      stageGddProposals?: PlanLearnViewState['stageGddProposals'];
    } = {}
  ): Pick<
    PlanLearnViewState,
    | 'blueprintTimingEvidenceByKey'
    | 'blueprintAmountEvidenceByKey'
    | 'stageGddEvidenceByKey'
  > {
    const blueprintTimingProposals =
      overrides.blueprintTimingProposals ?? this.view?.control.blueprintTimingProposals ?? [];
    const blueprintAmountProposals =
      overrides.blueprintAmountProposals ?? this.view?.control.blueprintAmountProposals ?? [];
    const stageGddProposals =
      overrides.stageGddProposals ?? this.view?.control.stageGddProposals ?? [];

    return {
      blueprintTimingEvidenceByKey: buildLearnProposalEvidenceMap(
        blueprintTimingProposals,
        this.evidenceSources,
        buildBlueprintTimingProposalEvidence,
        (proposal) => `${proposal.cropId}-${proposal.category}`
      ),
      blueprintAmountEvidenceByKey: buildLearnProposalEvidenceMap(
        blueprintAmountProposals,
        this.evidenceSources,
        buildBlueprintAmountProposalEvidence,
        blueprintAmountProposalEvidenceKey
      ),
      stageGddEvidenceByKey: buildLearnProposalEvidenceMap(
        stageGddProposals,
        this.evidenceSources,
        buildStageGddProposalEvidence,
        (proposal) => `${proposal.cropId}-${proposal.stageId}`
      )
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
