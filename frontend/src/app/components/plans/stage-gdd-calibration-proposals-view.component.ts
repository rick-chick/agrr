import { Component, EventEmitter, Input, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import type { LearnProposalEvidence } from '../../domain/plans/learn-proposal-evidence';
import { formatVarianceGddDelta } from '../../domain/plans/work-record-variance';
import { LearnProposalEvidencePanelComponent } from './learn-proposal-evidence-panel.component';
import {
  markStageGddProposalDismissed,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey,
  type LearnProposalApplicationStatus
} from '../../domain/plans/learn-proposal-application-progress';

@Component({
  selector: 'app-stage-gdd-calibration-proposals-view',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, LearnProposalEvidencePanelComponent],
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
                  <span
                    class="stage-gdd-calibration__status"
                    [class.stage-gdd-calibration__status--pending]="
                      proposalStatus(proposal) === 'applied_pending_confirmation'
                    "
                    [class.stage-gdd-calibration__status--dismissed]="
                      proposalStatus(proposal) === 'dismissed'
                    "
                  >
                    {{ statusLabel(proposalStatus(proposal)) | translate }}
                  </span>
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
                  <a
                    class="btn-secondary stage-gdd-calibration__cta"
                    [routerLink]="stageEditLink(proposal)"
                    [queryParams]="stageEditQueryParams(proposal)"
                  >
                    {{ 'plans.learn.stage_gdd_calibration.cta' | translate }}
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
  @Input({ required: true }) planId!: number;
  @Input() loading = false;
  @Input() proposals: StageGddCalibrationProposal[] = [];
  @Input() evidenceByKey: Record<string, LearnProposalEvidence> = {};
  @Output() progressChanged = new EventEmitter<void>();

  private refreshVersion = 0;

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
