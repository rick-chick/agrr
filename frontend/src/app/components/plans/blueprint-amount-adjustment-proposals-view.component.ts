import { Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { BlueprintAmountAdjustmentProposal } from '../../domain/plans/blueprint-amount-adjustment-proposal';
import { blueprintAmountProposalKey } from '../../domain/plans/blueprint-amount-adjustment-proposal';
import type { LearnProposalEvidence } from '../../domain/plans/learn-proposal-evidence';
import { formatPlanTaskScheduleAmountDeltaLabel } from '../../domain/work-schedule/format-plan-task-schedule-amount-delta';
import { cropPlanWizardQueryParams } from '../../domain/crops/plan-wizard-context';
import { LearnProposalEvidencePanelComponent } from './learn-proposal-evidence-panel.component';
import { LearnProposalConfidenceBadgeComponent } from './learn-proposal-confidence-badge.component';
import type { LearnProposalConfidence } from '../../domain/plans/resolve-learn-proposal-confidence';
import {
  bpAmountProposalProgressKey,
  markBpAmountProposalDismissed,
  resolveLearnProposalApplicationStatus,
  storeBlueprintTimingPrefill,
  type LearnProposalApplicationStatus
} from '../../domain/plans/learn-proposal-application-progress';

@Component({
  selector: 'app-blueprint-amount-adjustment-proposals-view',
  standalone: true,
  imports: [CommonModule, TranslateModule, LearnProposalEvidencePanelComponent, LearnProposalConfidenceBadgeComponent],
  template: `
    <section
      class="task-schedule-variance__section blueprint-amount-adjustment"
      aria-labelledby="blueprint-amount-adjustment-heading"
    >
      <h3 id="blueprint-amount-adjustment-heading" class="task-schedule-variance__section-title">
        {{ 'plans.learn.bp_amount_adjustment.title' | translate }}
      </h3>
      <p class="blueprint-amount-adjustment__lead">
        {{ 'plans.learn.bp_amount_adjustment.lead' | translate }}
      </p>

      @if (loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (proposals.length === 0) {
        <p class="blueprint-amount-adjustment__empty">
          {{ 'plans.learn.bp_amount_adjustment.empty' | translate }}
        </p>
      } @else {
        <ul class="blueprint-amount-adjustment__list">
          @for (proposal of proposals; track proposalKey(proposal)) {
            <li class="blueprint-amount-adjustment__item">
              <div class="blueprint-amount-adjustment__summary">
                <div class="blueprint-amount-adjustment__header">
                  <p class="blueprint-amount-adjustment__name">
                    {{ proposal.cropName }} — {{ categoryLabel(proposal.category) | translate }}
                    · {{ taskTypeLabel(proposal.taskType) | translate }}
                  </p>
                  <div class="blueprint-amount-adjustment__badges">
                    <app-learn-proposal-confidence-badge [confidence]="proposalConfidence" />
                    <span
                      class="blueprint-amount-adjustment__status"
                      [class.blueprint-amount-adjustment__status--dismissed]="
                        proposalStatus(proposal) === 'dismissed'
                      "
                    >
                      {{ statusLabel(proposalStatus(proposal)) | translate }}
                    </span>
                  </div>
                </div>
                <p class="blueprint-amount-adjustment__delta">
                  {{
                    'plans.learn.bp_amount_adjustment.delta_label'
                      | translate: { delta: deltaLabel(proposal) }
                  }}
                </p>
                <p class="blueprint-amount-adjustment__meta">
                  {{
                    'plans.learn.bp_amount_adjustment.affected_count'
                      | translate: { count: proposal.affectedBlueprintCount }
                  }}
                </p>
                <app-learn-proposal-evidence-panel
                  [evidence]="evidenceFor(proposal)"
                  toggleLabelKey="plans.learn.bp_amount_adjustment.evidence.toggle"
                  rationaleKey="plans.learn.bp_amount_adjustment.evidence.rationale"
                  recordsTitleKey="plans.learn.bp_amount_adjustment.evidence.records_title"
                  recordLabelKey="plans.learn.bp_amount_adjustment.evidence.record"
                />
              </div>
              <div class="blueprint-amount-adjustment__actions">
                @if (canDismiss(proposal)) {
                  <button
                    type="button"
                    class="btn-secondary blueprint-amount-adjustment__dismiss"
                    (click)="dismissProposal(proposal)"
                  >
                    {{ 'plans.learn.proposal.dismiss' | translate }}
                  </button>
                }
                <button
                  type="button"
                  class="btn-secondary blueprint-amount-adjustment__detail-edit"
                  (click)="openDetailEdit(proposal)"
                >
                  {{ 'plans.learn.bp_amount_adjustment.detail_edit' | translate }}
                </button>
              </div>
            </li>
          }
        </ul>
      }
    </section>
  `,
  styleUrls: ['./blueprint-amount-adjustment-proposals-view.component.css']
})
export class BlueprintAmountAdjustmentProposalsViewComponent {
  private readonly router = inject(Router);

  @Input({ required: true }) planId!: number;
  @Input() loading = false;
  @Input() proposals: BlueprintAmountAdjustmentProposal[] = [];
  @Input() evidenceByKey: Record<string, LearnProposalEvidence> = {};
  @Input() proposalConfidence: LearnProposalConfidence = 'high';
  @Output() progressChanged = new EventEmitter<void>();

  private refreshVersion = 0;

  proposalKey(proposal: BlueprintAmountAdjustmentProposal): string {
    return blueprintAmountProposalKey(proposal.cropId, proposal.category, proposal.taskType);
  }

  evidenceFor(proposal: BlueprintAmountAdjustmentProposal): LearnProposalEvidence | null {
    return this.evidenceByKey[this.proposalKey(proposal)] ?? null;
  }

  categoryLabel(category: string): string {
    return `plans.learn.bp_amount_adjustment.category.${category}`;
  }

  taskTypeLabel(taskType: string): string {
    return `plans.learn.bp_amount_adjustment.task_type.${taskType}`;
  }

  deltaLabel(proposal: BlueprintAmountAdjustmentProposal): string {
    return formatPlanTaskScheduleAmountDeltaLabel(
      proposal.averageAmountDelta,
      proposal.amountUnit
    );
  }

  openDetailEdit(proposal: BlueprintAmountAdjustmentProposal): void {
    storeBlueprintTimingPrefill(this.planId, proposal.cropId, proposal.proposalBody);
    void this.router.navigate(['/crops', proposal.cropId, 'setup_proposal'], {
      queryParams: cropPlanWizardQueryParams(this.planId, 'learn')
    });
  }

  proposalStatus(proposal: BlueprintAmountAdjustmentProposal): LearnProposalApplicationStatus {
    void this.refreshVersion;
    return resolveLearnProposalApplicationStatus(
      this.planId,
      bpAmountProposalProgressKey(proposal.cropId, proposal.category, proposal.taskType)
    );
  }

  canDismiss(proposal: BlueprintAmountAdjustmentProposal): boolean {
    return this.proposalStatus(proposal) === 'not_started';
  }

  dismissProposal(proposal: BlueprintAmountAdjustmentProposal): void {
    markBpAmountProposalDismissed(this.planId, {
      cropId: proposal.cropId,
      category: proposal.category,
      taskType: proposal.taskType
    });
    this.refreshVersion += 1;
    this.progressChanged.emit();
  }

  statusLabel(status: LearnProposalApplicationStatus): string {
    return `plans.learn.application_progress.status.${status}`;
  }
}
