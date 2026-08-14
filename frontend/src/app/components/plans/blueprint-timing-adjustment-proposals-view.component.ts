import { Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import type { LearnProposalEvidence } from '../../domain/plans/learn-proposal-evidence';
import { blueprintTimingPrefillStorageKey } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import { formatPlanTaskScheduleAverageDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';
import { cropPlanWizardQueryParams } from '../../domain/crops/plan-wizard-context';
import { LearnProposalEvidencePanelComponent } from './learn-proposal-evidence-panel.component';
import {
  bpTimingProposalProgressKey,
  markBpTimingProposalDismissed,
  resolveLearnProposalApplicationStatus,
  storeLearnBpTimingApplyContext,
  type LearnProposalApplicationStatus
} from '../../domain/plans/learn-proposal-application-progress';
import { ApplyBpTimingProposalFromLearnUseCase } from '../../usecase/plans/apply-bp-timing-proposal-from-learn.usecase';
import { DryRunBpTimingProposalFromLearnUseCase } from '../../usecase/plans/dry-run-bp-timing-proposal-from-learn.usecase';
import { LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS } from '../../usecase/plans/learn-proposal-inline-apply.providers';

@Component({
  selector: 'app-blueprint-timing-adjustment-proposals-view',
  standalone: true,
  imports: [CommonModule, TranslateModule, LearnProposalEvidencePanelComponent],
  providers: [...LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS],
  template: `
    <section
      class="task-schedule-variance__section blueprint-timing-adjustment"
      aria-labelledby="blueprint-timing-adjustment-heading"
    >
      <h3 id="blueprint-timing-adjustment-heading" class="task-schedule-variance__section-title">
        {{ 'plans.learn.bp_timing_adjustment.title' | translate }}
      </h3>
      <p class="blueprint-timing-adjustment__lead">
        {{ 'plans.learn.bp_timing_adjustment.lead' | translate }}
      </p>

      @if (loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (proposals.length === 0) {
        <p class="blueprint-timing-adjustment__empty">
          {{ 'plans.learn.bp_timing_adjustment.empty' | translate }}
        </p>
      } @else {
        <ul class="blueprint-timing-adjustment__list">
          @for (proposal of proposals; track proposalKey(proposal)) {
            <li class="blueprint-timing-adjustment__item">
              <div class="blueprint-timing-adjustment__summary">
                <div class="blueprint-timing-adjustment__header">
                  <p class="blueprint-timing-adjustment__name">
                    {{ proposal.cropName }} — {{ categoryLabel(proposal.category) | translate }}
                  </p>
                  <span
                    class="blueprint-timing-adjustment__status"
                    [class.blueprint-timing-adjustment__status--pending]="
                      proposalStatus(proposal) === 'applied_pending_confirmation'
                    "
                    [class.blueprint-timing-adjustment__status--confirmed]="
                      proposalStatus(proposal) === 'confirmed'
                    "
                    [class.blueprint-timing-adjustment__status--dismissed]="
                      proposalStatus(proposal) === 'dismissed'
                    "
                  >
                    {{ statusLabel(proposalStatus(proposal)) | translate }}
                  </span>
                </div>
                <p class="blueprint-timing-adjustment__delta">
                  {{
                    'plans.learn.bp_timing_adjustment.delta_label'
                      | translate: { delta: deltaLabel(proposal.averageDeltaDays) }
                  }}
                </p>
                <p class="blueprint-timing-adjustment__meta">
                  {{
                    'plans.learn.bp_timing_adjustment.affected_count'
                      | translate: { count: proposal.affectedBlueprintCount }
                  }}
                </p>
                @if (dryRunPreview(proposal)) {
                  <div class="blueprint-timing-adjustment__preview-panel" role="status">
                    <p class="blueprint-timing-adjustment__preview-title">
                      {{ 'plans.learn.bp_timing_adjustment.dry_run_result' | translate }}
                    </p>
                    <pre class="blueprint-timing-adjustment__preview-json">{{ dryRunPreview(proposal) }}</pre>
                  </div>
                }
                @if (applyError(proposal)) {
                  <p class="blueprint-timing-adjustment__error" role="alert">
                    {{ applyError(proposal) | translate }}
                  </p>
                }
                <app-learn-proposal-evidence-panel
                  [evidence]="evidenceFor(proposal)"
                  toggleLabelKey="plans.learn.bp_timing_adjustment.evidence.toggle"
                  rationaleKey="plans.learn.bp_timing_adjustment.evidence.rationale"
                  recordsTitleKey="plans.learn.bp_timing_adjustment.evidence.records_title"
                  recordLabelKey="plans.learn.bp_timing_adjustment.evidence.record"
                />
              </div>
              <div class="blueprint-timing-adjustment__actions">
                @if (canDismiss(proposal)) {
                  <button
                    type="button"
                    class="btn-secondary blueprint-timing-adjustment__dismiss"
                    (click)="dismissProposal(proposal)"
                  >
                    {{ 'plans.learn.proposal.dismiss' | translate }}
                  </button>
                }
                @if (canApply(proposal)) {
                  <button
                    type="button"
                    class="btn-secondary blueprint-timing-adjustment__preview"
                    [disabled]="isDryRunning(proposal)"
                    (click)="runDryRunPreview(proposal)"
                  >
                    {{
                      isDryRunning(proposal)
                        ? ('common.loading' | translate)
                        : ('plans.learn.bp_timing_adjustment.dry_run_preview' | translate)
                    }}
                  </button>
                  <button
                    type="button"
                    class="btn-primary blueprint-timing-adjustment__apply"
                    [disabled]="isApplying(proposal)"
                    (click)="applyProposal(proposal)"
                  >
                    {{
                      isApplying(proposal)
                        ? ('common.loading' | translate)
                        : ('plans.learn.bp_timing_adjustment.apply' | translate)
                    }}
                  </button>
                  <button
                    type="button"
                    class="btn-secondary blueprint-timing-adjustment__detail-edit"
                    (click)="openDetailEdit(proposal)"
                  >
                    {{ 'plans.learn.bp_timing_adjustment.detail_edit' | translate }}
                  </button>
                }
              </div>
            </li>
          }
        </ul>
      }
    </section>
  `,
  styleUrls: ['./blueprint-timing-adjustment-proposals-view.component.css']
})
export class BlueprintTimingAdjustmentProposalsViewComponent {
  private readonly router = inject(Router);
  private readonly applyUseCase = inject(ApplyBpTimingProposalFromLearnUseCase);
  private readonly dryRunUseCase = inject(DryRunBpTimingProposalFromLearnUseCase);

  @Input({ required: true }) planId!: number;
  @Input() loading = false;
  @Input() proposals: BlueprintTimingAdjustmentProposal[] = [];
  @Input() evidenceByKey: Record<string, LearnProposalEvidence> = {};
  @Output() progressChanged = new EventEmitter<void>();

  private refreshVersion = 0;
  private dryRunPreviews: Record<string, string> = {};
  private dryRunningKeys = new Set<string>();
  private applyingKeys = new Set<string>();
  private applyErrors: Record<string, string> = {};

  proposalKey(proposal: BlueprintTimingAdjustmentProposal): string {
    return `${proposal.cropId}-${proposal.category}`;
  }

  evidenceFor(proposal: BlueprintTimingAdjustmentProposal): LearnProposalEvidence | null {
    return this.evidenceByKey[this.proposalKey(proposal)] ?? null;
  }

  categoryLabel(category: string): string {
    return `plans.learn.bp_timing_adjustment.category.${category}`;
  }

  deltaLabel(deltaDays: number): string {
    return formatPlanTaskScheduleAverageDeltaDaysLabel(deltaDays);
  }

  openDetailEdit(proposal: BlueprintTimingAdjustmentProposal): void {
    sessionStorage.setItem(
      blueprintTimingPrefillStorageKey(proposal.cropId),
      JSON.stringify(proposal.proposalBody)
    );
    storeLearnBpTimingApplyContext(proposal.cropId, {
      planId: this.planId,
      cropId: proposal.cropId,
      cropName: proposal.cropName,
      category: proposal.category
    });
    void this.router.navigate(['/crops', proposal.cropId, 'setup_proposal'], {
      queryParams: cropPlanWizardQueryParams(this.planId, 'learn')
    });
  }

  proposalStatus(proposal: BlueprintTimingAdjustmentProposal): LearnProposalApplicationStatus {
    void this.refreshVersion;
    return resolveLearnProposalApplicationStatus(
      this.planId,
      bpTimingProposalProgressKey(proposal.cropId, proposal.category)
    );
  }

  canDismiss(proposal: BlueprintTimingAdjustmentProposal): boolean {
    return this.proposalStatus(proposal) === 'not_started';
  }

  canApply(proposal: BlueprintTimingAdjustmentProposal): boolean {
    return this.proposalStatus(proposal) === 'not_started';
  }

  dryRunPreview(proposal: BlueprintTimingAdjustmentProposal): string | null {
    void this.refreshVersion;
    return this.dryRunPreviews[this.proposalKey(proposal)] ?? null;
  }

  isDryRunning(proposal: BlueprintTimingAdjustmentProposal): boolean {
    void this.refreshVersion;
    return this.dryRunningKeys.has(this.proposalKey(proposal));
  }

  isApplying(proposal: BlueprintTimingAdjustmentProposal): boolean {
    void this.refreshVersion;
    return this.applyingKeys.has(this.proposalKey(proposal));
  }

  applyError(proposal: BlueprintTimingAdjustmentProposal): string | null {
    void this.refreshVersion;
    return this.applyErrors[this.proposalKey(proposal)] ?? null;
  }

  runDryRunPreview(proposal: BlueprintTimingAdjustmentProposal): void {
    const key = this.proposalKey(proposal);
    if (this.isDryRunning(proposal)) {
      return;
    }
    this.dryRunningKeys.add(key);
    delete this.applyErrors[key];
    this.refreshVersion += 1;

    this.dryRunUseCase.execute({
      cropId: proposal.cropId,
      proposal: proposal.proposalBody,
      onSuccess: (previewJson) => {
        this.dryRunningKeys.delete(key);
        this.dryRunPreviews[key] = previewJson;
        this.refreshVersion += 1;
      },
      onError: (message) => {
        this.dryRunningKeys.delete(key);
        this.applyErrors[key] = message;
        this.refreshVersion += 1;
      }
    });
  }

  applyProposal(proposal: BlueprintTimingAdjustmentProposal): void {
    const key = this.proposalKey(proposal);
    if (this.isApplying(proposal)) {
      return;
    }
    this.applyingKeys.add(key);
    delete this.applyErrors[key];
    this.refreshVersion += 1;

    this.applyUseCase.execute({
      planId: this.planId,
      cropId: proposal.cropId,
      category: proposal.category,
      proposal: proposal.proposalBody,
      onSuccess: () => {
        this.applyingKeys.delete(key);
        delete this.dryRunPreviews[key];
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

  dismissProposal(proposal: BlueprintTimingAdjustmentProposal): void {
    markBpTimingProposalDismissed(this.planId, {
      cropId: proposal.cropId,
      category: proposal.category
    });
    this.refreshVersion += 1;
    this.progressChanged.emit();
  }

  statusLabel(status: LearnProposalApplicationStatus): string {
    return `plans.learn.application_progress.status.${status}`;
  }
}
