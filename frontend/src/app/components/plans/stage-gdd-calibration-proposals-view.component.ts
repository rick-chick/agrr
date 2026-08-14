import { Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import type { LearnProposalEvidence } from '../../domain/plans/learn-proposal-evidence';
import { formatVarianceGddDelta } from '../../domain/plans/work-record-variance';
import { LearnProposalEvidencePanelComponent } from './learn-proposal-evidence-panel.component';
import { LearnProposalConfidenceBadgeComponent } from './learn-proposal-confidence-badge.component';
import type { LearnProposalConfidence } from '../../domain/plans/resolve-learn-proposal-confidence';
import {
  markStageGddProposalDismissed,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey,
  type LearnProposalApplicationStatus
} from '../../domain/plans/learn-proposal-application-progress';
import { ApplyStageGddCalibrationFromLearnUseCase } from '../../usecase/plans/apply-stage-gdd-calibration-from-learn.usecase';
import { LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS } from '../../usecase/plans/learn-proposal-inline-apply.providers';

@Component({
  selector: 'app-stage-gdd-calibration-proposals-view',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, LearnProposalEvidencePanelComponent, LearnProposalConfidenceBadgeComponent],
  providers: [...LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS],
  template: `
    <section
      class="task-schedule-variance__section stage-gdd-calibration"
      aria-labelledby="stage-gdd-calibration-heading"
    >
      <h3 id="stage-gdd-calibration-heading" class="task-schedule-variance__section-title">
        {{ 'plans.learn.stage_gdd_calibration.title' | translate }}
      </h3>
      <p class="stage-gdd-calibration__lead">
        {{ 'plans.learn.stage_gdd_calibration.lead' | translate }}
      </p>

      @if (loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (proposals.length === 0) {
        <p class="stage-gdd-calibration__empty">
          {{ 'plans.learn.stage_gdd_calibration.empty' | translate }}
        </p>
      } @else {
        <ul class="stage-gdd-calibration__list">
          @for (proposal of proposals; track proposalKey(proposal)) {
            <li class="stage-gdd-calibration__item">
              <div class="stage-gdd-calibration__summary">
                <div class="stage-gdd-calibration__header">
                  <p class="stage-gdd-calibration__stage-name">
                    {{ proposal.cropName }} — {{ proposal.stageName }}
                  </p>
                  <div class="stage-gdd-calibration__badges">
                    <app-learn-proposal-confidence-badge [confidence]="proposalConfidence" />
                    <span
                    class="stage-gdd-calibration__status"
                    [class.stage-gdd-calibration__status--pending]="
                      proposalStatus(proposal) === 'applied_pending_confirmation'
                    "
                    [class.stage-gdd-calibration__status--confirmed]="
                      proposalStatus(proposal) === 'confirmed'
                    "
                    [class.stage-gdd-calibration__status--dismissed]="
                      proposalStatus(proposal) === 'dismissed'
                    "
                  >
                    {{ statusLabel(proposalStatus(proposal)) | translate }}
                  </span>
                  </div>
                </div>
                <p class="stage-gdd-calibration__delta">
                  {{
                    'plans.learn.stage_gdd_calibration.delta_label'
                      | translate: { delta: formatDelta(proposal.averageGddDelta) }
                  }}
                </p>
                <p class="stage-gdd-calibration__proposal-value">
                  {{
                    'plans.learn.stage_gdd_calibration.proposed_value'
                      | translate
                        : {
                            current: formatRequiredGdd(proposal.currentRequiredGdd),
                            proposed: formatRequiredGdd(proposal.proposedRequiredGdd)
                          }
                  }}
                </p>
                @if (isPreviewOpen(proposal)) {
                  <p class="stage-gdd-calibration__preview-panel" role="status">
                    {{
                      'plans.learn.stage_gdd_calibration.preview_panel'
                        | translate
                          : {
                              proposed: formatRequiredGdd(proposal.proposedRequiredGdd)
                            }
                    }}
                  </p>
                }
                @if (applyError(proposal)) {
                  <p class="stage-gdd-calibration__error" role="alert">
                    {{ applyError(proposal) | translate }}
                  </p>
                }
                <app-learn-proposal-evidence-panel
                  [evidence]="evidenceFor(proposal)"
                  toggleLabelKey="plans.learn.stage_gdd_calibration.evidence.toggle"
                  rationaleKey="plans.learn.stage_gdd_calibration.evidence.rationale"
                  recordsTitleKey="plans.learn.stage_gdd_calibration.evidence.records_title"
                  recordLabelKey="plans.learn.stage_gdd_calibration.evidence.record"
                />
              </div>
              <div class="stage-gdd-calibration__actions">
                @if (canDismiss(proposal)) {
                  <button
                    type="button"
                    class="btn-secondary stage-gdd-calibration__dismiss"
                    (click)="dismissProposal(proposal)"
                  >
                    {{ 'plans.learn.proposal.dismiss' | translate }}
                  </button>
                }
                @if (canApply(proposal)) {
                  <button
                    type="button"
                    class="btn-secondary stage-gdd-calibration__preview"
                    (click)="togglePreview(proposal)"
                  >
                    {{ 'plans.learn.stage_gdd_calibration.preview' | translate }}
                  </button>
                  <button
                    type="button"
                    class="btn-primary stage-gdd-calibration__apply"
                    [disabled]="isApplying(proposal)"
                    (click)="applyProposal(proposal)"
                  >
                    {{
                      isApplying(proposal)
                        ? ('common.loading' | translate)
                        : ('plans.learn.stage_gdd_calibration.apply' | translate)
                    }}
                  </button>
                  <a
                    class="btn-secondary stage-gdd-calibration__detail-edit"
                    [routerLink]="stageEditLink(proposal)"
                    [queryParams]="stageEditQueryParams(proposal)"
                  >
                    {{ 'plans.learn.stage_gdd_calibration.detail_edit' | translate }}
                  </a>
                }
              </div>
            </li>
          }
        </ul>
      }
    </section>
  `,
  styleUrls: ['./stage-gdd-calibration-proposals-view.component.css']
})
export class StageGddCalibrationProposalsViewComponent {
  private readonly applyUseCase = inject(ApplyStageGddCalibrationFromLearnUseCase);

  @Input({ required: true }) planId!: number;
  @Input() loading = false;
  @Input() proposals: StageGddCalibrationProposal[] = [];
  @Input() evidenceByKey: Record<string, LearnProposalEvidence> = {};
  @Input() proposalConfidence: LearnProposalConfidence = 'high';
  @Output() progressChanged = new EventEmitter<void>();

  private refreshVersion = 0;
  private previewOpenKeys = new Set<string>();
  private applyingKeys = new Set<string>();
  private applyErrors: Record<string, string> = {};

  proposalKey(proposal: StageGddCalibrationProposal): string {
    return `${proposal.cropId}-${proposal.stageId}`;
  }

  evidenceFor(proposal: StageGddCalibrationProposal): LearnProposalEvidence | null {
    return this.evidenceByKey[this.proposalKey(proposal)] ?? null;
  }

  formatDelta(delta: number): string {
    return formatVarianceGddDelta(delta);
  }

  formatRequiredGdd(value: number | null): string {
    return value == null ? '—' : String(value);
  }

  stageEditLink(proposal: StageGddCalibrationProposal): string[] {
    return ['/crops', String(proposal.cropId), 'stages', String(proposal.stageId), 'edit'];
  }

  stageEditQueryParams(proposal: StageGddCalibrationProposal): Record<string, string | number> {
    return {
      fromPlan: this.planId,
      returnTo: 'learn',
      proposedRequiredGdd: proposal.proposedRequiredGdd ?? ''
    };
  }

  proposalStatus(proposal: StageGddCalibrationProposal): LearnProposalApplicationStatus {
    void this.refreshVersion;
    return resolveLearnProposalApplicationStatus(
      this.planId,
      stageGddProposalProgressKey(proposal.cropId, proposal.stageId)
    );
  }

  canDismiss(proposal: StageGddCalibrationProposal): boolean {
    return this.proposalStatus(proposal) === 'not_started';
  }

  canApply(proposal: StageGddCalibrationProposal): boolean {
    return this.proposalStatus(proposal) === 'not_started';
  }

  isPreviewOpen(proposal: StageGddCalibrationProposal): boolean {
    void this.refreshVersion;
    return this.previewOpenKeys.has(this.proposalKey(proposal));
  }

  isApplying(proposal: StageGddCalibrationProposal): boolean {
    void this.refreshVersion;
    return this.applyingKeys.has(this.proposalKey(proposal));
  }

  applyError(proposal: StageGddCalibrationProposal): string | null {
    void this.refreshVersion;
    return this.applyErrors[this.proposalKey(proposal)] ?? null;
  }

  togglePreview(proposal: StageGddCalibrationProposal): void {
    const key = this.proposalKey(proposal);
    if (this.previewOpenKeys.has(key)) {
      this.previewOpenKeys.delete(key);
    } else {
      this.previewOpenKeys.add(key);
    }
    this.refreshVersion += 1;
  }

  applyProposal(proposal: StageGddCalibrationProposal): void {
    if (proposal.proposedRequiredGdd == null || this.isApplying(proposal)) {
      return;
    }
    const key = this.proposalKey(proposal);
    this.applyingKeys.add(key);
    delete this.applyErrors[key];
    this.refreshVersion += 1;

    this.applyUseCase.execute({
      planId: this.planId,
      cropId: proposal.cropId,
      stageId: proposal.stageId,
      proposedRequiredGdd: proposal.proposedRequiredGdd,
      onSuccess: () => {
        this.applyingKeys.delete(key);
        this.previewOpenKeys.delete(key);
        this.refreshVersion += 1;
        this.progressChanged.emit();
      },
      onError: (message) => {
        this.applyingKeys.delete(key);
        this.applyErrors[key] = message;
        this.refreshVersion += 1;
      }
    });
  }

  dismissProposal(proposal: StageGddCalibrationProposal): void {
    markStageGddProposalDismissed(this.planId, {
      cropId: proposal.cropId,
      stageId: proposal.stageId
    });
    this.refreshVersion += 1;
    this.progressChanged.emit();
  }

  statusLabel(status: LearnProposalApplicationStatus): string {
    return `plans.learn.application_progress.status.${status}`;
  }
}
