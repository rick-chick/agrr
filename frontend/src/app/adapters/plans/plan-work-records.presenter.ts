import { Injectable } from '@angular/core';
import { PlanWorkRecordsView } from '../../components/plans/plan-work-records.view';
import { WorkRecordSheetSavedEvent } from '../../components/plans/work-record-sheet.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { WorkRecordSaveToastContext } from '../../domain/plans/work-record-save-toast';
import type { WorkRecordSaveImpactViewModel } from '../../domain/plans/work-record-save-impact';
import { LoadWorkRecordsDataDto } from '../../usecase/plans/load-work-records.dtos';
import { LoadWorkRecordsOutputPort } from '../../usecase/plans/load-work-records.output-port';
import { PlanVsActualSummaryDataDto } from '../../usecase/plans/load-plan-vs-actual-summary.output-port';
import {
  applyPlanSaveImpactSummary,
  beginPlanSaveImpactLoad,
  emptyPlanSaveImpactViewFields,
  PendingSaveImpactRequest,
  planSaveImpactErrorFields
} from './plan-save-impact.presenter.helpers';

@Injectable()
export class PlanWorkRecordsPresenter implements LoadWorkRecordsOutputPort {
  private view: PlanWorkRecordsView | null = null;
  private pendingSaveImpactRequest: PendingSaveImpactRequest | null = null;
  private saveImpactLoadGeneration = 0;

  setView(view: PlanWorkRecordsView): void {
    this.view = view;
  }

  present(dto: LoadWorkRecordsDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      plan: dto.plan,
      groups: dto.groups
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      plan: null,
      groups: [],
      pendingSaveImpactLoadGeneration: 0,
      ...emptyPlanSaveImpactViewFields
    };
  }

  queueSaveImpactAfterSave(event: WorkRecordSheetSavedEvent): number {
    if (!this.view || event.mode === 'edit') {
      return 0;
    }
    const context = event.saveToastContext ?? null;
    const fields = this.beginSaveImpactLoadFields(event, context);
    this.view.control = {
      ...this.view.control,
      ...fields
    };
    return fields.pendingSaveImpactLoadGeneration;
  }

  presentSaveImpactSummary(dto: PlanVsActualSummaryDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const applied = applyPlanSaveImpactSummary(
      this.pendingSaveImpactRequest,
      dto.loadGeneration,
      this.saveImpactLoadGeneration,
      dto
    );
    if (!applied) {
      return;
    }
    this.pendingSaveImpactRequest = applied.pending;
    this.view.control = {
      ...this.view.control,
      ...applied.fields,
      pendingSaveImpactLoadGeneration: 0
    };
  }

  onSaveImpactError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.pendingSaveImpactRequest = null;
    this.view.control = {
      ...this.view.control,
      ...planSaveImpactErrorFields(dto.message),
      pendingSaveImpactLoadGeneration: 0
    };
  }

  dismissSaveImpact(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      ...emptyPlanSaveImpactViewFields
    };
  }

  private beginSaveImpactLoadFields(
    event: WorkRecordSheetSavedEvent,
    context: WorkRecordSaveToastContext | null
  ): {
    pendingSaveImpactLoadGeneration: number;
    saveImpact: WorkRecordSaveImpactViewModel | null;
    saveImpactLoading: boolean;
    saveImpactError: string | null;
  } {
    this.saveImpactLoadGeneration += 1;
    this.pendingSaveImpactRequest = { event, context };
    const began = beginPlanSaveImpactLoad(this.pendingSaveImpactRequest, this.saveImpactLoadGeneration);
    return {
      pendingSaveImpactLoadGeneration: this.saveImpactLoadGeneration,
      ...began.fields
    };
  }
}
