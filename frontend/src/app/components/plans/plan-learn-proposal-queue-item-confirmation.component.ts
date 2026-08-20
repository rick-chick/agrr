import { CommonModule } from '@angular/common';
import { ChangeDetectorRef, Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import type { UnifiedLearnProposalQueueItem } from '../../domain/plans/build-unified-learn-proposal-queue';
import { cropPlanWizardQueryParams } from '../../domain/crops/plan-wizard-context';
import type { LearnProposalEvidence } from '../../domain/plans/learn-proposal-evidence';
import {
  bpTimingProposalProgressKey,
  markBpTimingProposalDismissed,
  markStageGddProposalDismissed,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey,
  storeBlueprintTimingPrefill,
  storeLearnBpTimingApplyContext,
  type LearnProposalApplicationStatus
} from '../../domain/plans/learn-proposal-application-progress';
import {
  resolveLearnQueueItemInlineApplyMode,
  type LearnQueueItemInlineApplyMode
} from '../../domain/plans/resolve-learn-queue-item-inline-apply';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import { formatVarianceGddDelta } from '../../domain/plans/work-record-variance';
import { formatPlanTaskScheduleAverageDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';
import { ApplyBpTimingProposalFromLearnUseCase } from '../../usecase/plans/apply-bp-timing-proposal-from-learn.usecase';
import { ApplyStageGddCalibrationFromLearnUseCase } from '../../usecase/plans/apply-stage-gdd-calibration-from-learn.usecase';
import { DryRunBpTimingProposalFromLearnUseCase } from '../../usecase/plans/dry-run-bp-timing-proposal-from-learn.usecase';
import { LearnProposalEvidencePanelComponent } from './learn-proposal-evidence-panel.component';

@Component({
  selector: 'app-plan-learn-proposal-queue-item-confirmation',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, LearnProposalEvidencePanelComponent],
  template: `
    @if (inlineApplyMode) {
      <div
        class="learn-proposal-queue__inline-confirm"
        [attr.data-testid]="'queue-inline-confirm-' + item.id"
      >
        @if (stageGddProposal; as proposal) {
          <p class="learn-proposal-queue__inline-delta">
            {{
              'plans.learn.stage_gdd_calibration.delta_label'
                | translate: { delta: formatGddDelta(proposal.averageGddDelta) }
            }}
          </p>
          <p class="learn-proposal-queue__inline-value">
            {{
              'plans.learn.stage_gdd_calibration.proposed_value'
                | translate
                  : {
                      current: formatRequiredGdd(proposal.currentRequiredGdd),
                      proposed: formatRequiredGdd(proposal.proposedRequiredGdd)
                    }
            }}
          </p>
          @if (isPreviewOpen) {
            <p class="learn-proposal-queue__inline-preview" role="status">
              {{
                'plans.learn.stage_gdd_calibration.preview_panel'
                  | translate: { proposed: formatRequiredGdd(proposal.proposedRequiredGdd) }
              }}
            </p>
          }
        }
        @if (bpTimingProposal; as proposal) {
          <p class="learn-proposal-queue__inline-delta">
            {{
              'plans.learn.bp_timing_adjustment.delta_label'
                | translate: { delta: formatDaysDelta(proposal.averageDeltaDays) }
            }}
          </p>
          @if (dryRunPreview) {
            <div class="learn-proposal-queue__inline-preview" role="status">
              <p>{{ 'plans.learn.bp_timing_adjustment.dry_run_result' | translate }}</p>
              <pre>{{ dryRunPreview }}</pre>
            </div>
          }
        }
        @if (evidence) {
          <app-learn-proposal-evidence-panel
            [evidence]="evidence"
            [toggleLabelKey]="evidenceToggleKey"
            [rationaleKey]="evidenceRationaleKey"
            [recordsTitleKey]="evidenceRecordsTitleKey"
            [recordLabelKey]="evidenceRecordLabelKey"
          />
        }
        @if (applyError) {
          <p class="learn-proposal-queue__inline-error" role="alert">{{ applyError | translate }}</p>
        }
        <div class="learn-proposal-queue__inline-actions">
          @if (canDismiss) {
            <button type="button" class="btn-secondary" (click)="dismiss()">
              {{ 'plans.learn.proposal.dismiss' | translate }}
            </button>
          }
          @if (inlineApplyMode === 'stage_gdd') {
            <button type="button" class="btn-secondary" (click)="togglePreview()">
              {{ 'plans.learn.stage_gdd_calibration.preview' | translate }}
            </button>
            <button
              type="button"
              class="btn-primary"
              data-testid="queue-inline-apply"
              [disabled]="applying"
              (click)="applyStageGdd()"
            >
              {{
                applying
                  ? ('common.loading' | translate)
                  : ('plans.learn.stage_gdd_calibration.apply' | translate)
              }}
            </button>
            <a
              class="btn-secondary"
              data-testid="queue-inline-detail-edit"
              [routerLink]="stageEditLink()"
              [queryParams]="stageEditQueryParams()"
            >
              {{ 'plans.learn.stage_gdd_calibration.detail_edit' | translate }}
            </a>
          } @else if (inlineApplyMode === 'bp_timing') {
            <button
              type="button"
              class="btn-secondary"
              [disabled]="dryRunning"
              (click)="runDryRun()"
            >
              {{
                dryRunning
                  ? ('common.loading' | translate)
                  : ('plans.learn.bp_timing_adjustment.dry_run_preview' | translate)
              }}
            </button>
            <button
              type="button"
              class="btn-primary"
              data-testid="queue-inline-apply"
              [disabled]="applying"
              (click)="applyBpTiming()"
            >
              {{
                applying
                  ? ('common.loading' | translate)
                  : ('plans.learn.bp_timing_adjustment.apply' | translate)
              }}
            </button>
            <button
              type="button"
              class="btn-secondary"
              data-testid="queue-inline-detail-edit"
              (click)="openBpTimingDetailEdit()"
            >
              {{ 'plans.learn.bp_timing_adjustment.detail_edit' | translate }}
            </button>
          } @else {
            @if (stageGddProposal) {
              <a
                class="btn-primary"
                data-testid="queue-inline-detail-edit"
                [routerLink]="stageEditLink()"
                [queryParams]="stageEditQueryParams()"
              >
                {{ 'plans.learn.stage_gdd_calibration.detail_edit' | translate }}
              </a>
            }
            @if (bpTimingProposal) {
              <button
                type="button"
                class="btn-primary"
                data-testid="queue-inline-detail-edit"
                (click)="openBpTimingDetailEdit()"
              >
                {{ 'plans.learn.bp_timing_adjustment.detail_edit' | translate }}
              </button>
            }
          }
        </div>
      </div>
    }
  `,
  styleUrls: ['./plan-learn-proposal-queue-item-confirmation.component.css']
})
export class PlanLearnProposalQueueItemConfirmationComponent {
  private readonly applyStageGddUseCase = inject(ApplyStageGddCalibrationFromLearnUseCase);
  private readonly applyBpTimingUseCase = inject(ApplyBpTimingProposalFromLearnUseCase);
  private readonly dryRunBpTimingUseCase = inject(DryRunBpTimingProposalFromLearnUseCase);
  private readonly router = inject(Router);
  private readonly cdr = inject(ChangeDetectorRef);

  @Input({ required: true }) planId!: number;
  @Input({ required: true }) item!: UnifiedLearnProposalQueueItem;
  @Input() stageGddProposal: StageGddCalibrationProposal | null = null;
  @Input() bpTimingProposal: BlueprintTimingAdjustmentProposal | null = null;
  @Input() evidence: LearnProposalEvidence | null = null;
  @Input() evidenceToggleKey = 'plans.learn.stage_gdd_calibration.evidence.toggle';
  @Input() evidenceRationaleKey = 'plans.learn.stage_gdd_calibration.evidence.rationale';
  @Input() evidenceRecordsTitleKey = 'plans.learn.stage_gdd_calibration.evidence.records_title';
  @Input() evidenceRecordLabelKey = 'plans.learn.stage_gdd_calibration.evidence.record';
  @Output() progressChanged = new EventEmitter<void>();

  applying = false;
  dryRunning = false;
  isPreviewOpen = false;
  dryRunPreview: string | null = null;
  applyError: string | null = null;
  private refreshVersion = 0;

  get inlineApplyMode(): LearnQueueItemInlineApplyMode | null {
    return resolveLearnQueueItemInlineApplyMode(
      this.item,
      this.stageGddProposal ? [this.stageGddProposal] : [],
      this.bpTimingProposal ? [this.bpTimingProposal] : []
    );
  }

  get canDismiss(): boolean {
    void this.refreshVersion;
    return this.proposalStatus() === 'not_started';
  }

  formatGddDelta(delta: number): string {
    return formatVarianceGddDelta(delta);
  }

  formatDaysDelta(delta: number): string {
    return formatPlanTaskScheduleAverageDeltaDaysLabel(delta);
  }

  formatRequiredGdd(value: number | null): string {
    return value == null ? '—' : String(value);
  }

  stageEditLink(): string[] {
    if (!this.stageGddProposal) {
      return [];
    }
    return [
      '/crops',
      String(this.stageGddProposal.cropId),
      'stages',
      String(this.stageGddProposal.stageId),
      'edit'
    ];
  }

  stageEditQueryParams(): Record<string, string | number> {
    if (!this.stageGddProposal) {
      return {};
    }
    return {
      fromPlan: this.planId,
      returnTo: 'learn',
      proposedRequiredGdd: this.stageGddProposal.proposedRequiredGdd ?? ''
    };
  }

  togglePreview(): void {
    this.isPreviewOpen = !this.isPreviewOpen;
    this.cdr.markForCheck();
  }

  dismiss(): void {
    if (this.stageGddProposal) {
      markStageGddProposalDismissed(this.planId, {
        cropId: this.stageGddProposal.cropId,
        stageId: this.stageGddProposal.stageId
      });
    } else if (this.bpTimingProposal) {
      markBpTimingProposalDismissed(this.planId, {
        cropId: this.bpTimingProposal.cropId,
        category: this.bpTimingProposal.category
      });
    }
    this.refreshVersion += 1;
    this.progressChanged.emit();
    this.cdr.markForCheck();
  }

  applyStageGdd(): void {
    if (!this.stageGddProposal || this.stageGddProposal.proposedRequiredGdd == null || this.applying) {
      return;
    }
    this.applying = true;
    this.applyError = null;
    this.cdr.markForCheck();

    this.applyStageGddUseCase.execute({
      planId: this.planId,
      cropId: this.stageGddProposal.cropId,
      cropName: this.stageGddProposal.cropName,
      stageId: this.stageGddProposal.stageId,
      stageName: this.stageGddProposal.stageName,
      proposedRequiredGdd: this.stageGddProposal.proposedRequiredGdd,
      onSuccess: () => {
        this.applying = false;
        this.isPreviewOpen = false;
        this.refreshVersion += 1;
        this.progressChanged.emit();
        this.cdr.markForCheck();
      },
      onError: (message) => {
        this.applying = false;
        this.applyError = message;
        this.cdr.markForCheck();
      }
    });
  }

  runDryRun(): void {
    if (!this.bpTimingProposal || this.dryRunning) {
      return;
    }
    this.dryRunning = true;
    this.applyError = null;
    this.cdr.markForCheck();

    this.dryRunBpTimingUseCase.execute({
      cropId: this.bpTimingProposal.cropId,
      proposal: this.bpTimingProposal.proposalBody,
      onSuccess: (previewJson) => {
        this.dryRunning = false;
        this.dryRunPreview = previewJson;
        this.cdr.markForCheck();
      },
      onError: (message) => {
        this.dryRunning = false;
        this.applyError = message;
        this.cdr.markForCheck();
      }
    });
  }

  applyBpTiming(): void {
    if (!this.bpTimingProposal || this.applying) {
      return;
    }
    this.applying = true;
    this.applyError = null;
    this.cdr.markForCheck();

    this.applyBpTimingUseCase.execute({
      planId: this.planId,
      cropId: this.bpTimingProposal.cropId,
      category: this.bpTimingProposal.category,
      proposal: this.bpTimingProposal.proposalBody,
      onSuccess: () => {
        this.applying = false;
        this.dryRunPreview = null;
        this.refreshVersion += 1;
        this.progressChanged.emit();
        this.cdr.markForCheck();
      },
      onError: (message) => {
        this.applying = false;
        this.applyError = message;
        this.cdr.markForCheck();
      }
    });
  }

  openBpTimingDetailEdit(): void {
    if (!this.bpTimingProposal) {
      return;
    }
    storeBlueprintTimingPrefill(this.planId, this.bpTimingProposal.cropId, this.bpTimingProposal.proposalBody);
    storeLearnBpTimingApplyContext(this.planId, {
      planId: this.planId,
      cropId: this.bpTimingProposal.cropId,
      cropName: this.bpTimingProposal.cropName,
      category: this.bpTimingProposal.category
    });
    void this.router.navigate(['/crops', this.bpTimingProposal.cropId, 'setup_proposal'], {
      queryParams: cropPlanWizardQueryParams(this.planId, 'learn')
    });
  }

  private proposalStatus(): LearnProposalApplicationStatus {
    if (this.stageGddProposal) {
      return resolveLearnProposalApplicationStatus(
        this.planId,
        stageGddProposalProgressKey(this.stageGddProposal.cropId, this.stageGddProposal.stageId)
      );
    }
    if (this.bpTimingProposal) {
      return resolveLearnProposalApplicationStatus(
        this.planId,
        bpTimingProposalProgressKey(this.bpTimingProposal.cropId, this.bpTimingProposal.category)
      );
    }
    return 'not_started';
  }
}
