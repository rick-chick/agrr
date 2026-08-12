import { Injectable } from '@angular/core';
import { PlanWorkRecordsView } from '../../components/plans/plan-work-records.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import {
  buildWorkRecordSaveImpactPanel,
  shouldShowWorkRecordSaveImpact,
  type WorkRecordSaveImpactRequest
} from '../../domain/plans/work-record-save-impact';
import { LoadWorkRecordsDataDto } from '../../usecase/plans/load-work-records.dtos';
import { LoadWorkRecordsOutputPort } from '../../usecase/plans/load-work-records.output-port';
import { PlanVsActualSummaryDataDto } from '../../usecase/plans/load-plan-vs-actual-summary.output-port';

@Injectable()
export class PlanWorkRecordsPresenter implements LoadWorkRecordsOutputPort {
  private view: PlanWorkRecordsView | null = null;
  private impactLoadGeneration = 0;
  private pendingImpactRequest: WorkRecordSaveImpactRequest | null = null;

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
      ...this.view.control,
      loading: false,
      error: dto.message,
      plan: null,
      groups: [],
      recordSaveImpactPanel: null,
      recordSaveImpactLoading: false,
      recordSaveImpactError: null
    };
  }

  beginImpactPreview(request: WorkRecordSaveImpactRequest): number | null {
    if (!shouldShowWorkRecordSaveImpact(request)) {
      this.pendingImpactRequest = null;
      return null;
    }
    this.pendingImpactRequest = request;
    this.impactLoadGeneration += 1;
    if (this.view) {
      this.view.control = {
        ...this.view.control,
        recordSaveImpactPanel: null,
        recordSaveImpactLoading: true,
        recordSaveImpactError: null
      };
    }
    return this.impactLoadGeneration;
  }

  presentImpactSummary(dto: PlanVsActualSummaryDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.loadGeneration !== this.impactLoadGeneration || !this.pendingImpactRequest) {
      return;
    }
    const panel = buildWorkRecordSaveImpactPanel(this.pendingImpactRequest, dto.summary);
    this.pendingImpactRequest = null;
    this.view.control = {
      ...this.view.control,
      recordSaveImpactPanel: panel,
      recordSaveImpactLoading: false,
      recordSaveImpactError: null
    };
  }

  onImpactError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.pendingImpactRequest = null;
    this.view.control = {
      ...this.view.control,
      recordSaveImpactPanel: null,
      recordSaveImpactLoading: false,
      recordSaveImpactError: dto.message
    };
  }

  dismissRecordSaveImpactPanel(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      recordSaveImpactPanel: null,
      recordSaveImpactLoading: false,
      recordSaveImpactError: null
    };
  }
}
