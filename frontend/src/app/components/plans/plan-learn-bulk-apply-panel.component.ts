import { CommonModule } from '@angular/common';
import { ChangeDetectorRef, Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import {
  buildLearnOrchestrationPipelineStartNavigation,
  storeLearnOrchestrationPipelineActive
} from '../../domain/plans/learn-master-update-orchestration';
import { hasConfirmedLearnProposalsWithoutDismissed } from '../../domain/plans/learn-bulk-apply-state';
import { countBulkApplicableLearnProposals } from '../../domain/plans/learn-safe-proposal';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import { BulkApplySafeLearnProposalsUseCase } from '../../usecase/plans/bulk-apply-safe-learn-proposals.usecase';
import { LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS } from '../../usecase/plans/learn-proposal-inline-apply.providers';

@Component({
  selector: 'app-plan-learn-bulk-apply-panel',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [...LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS, BulkApplySafeLearnProposalsUseCase],
  template: `
    @if (bulkApplicableCount > 0 || showStartPipelineCta) {
      <section
        class="learn-bulk-apply"
        aria-labelledby="learn-bulk-apply-heading"
      >
        <h3 id="learn-bulk-apply-heading" class="learn-bulk-apply__title">
          {{ 'plans.learn.bulk_apply.title' | translate }}
        </h3>
        @if (bulkApplicableCount > 0) {
          <p class="learn-bulk-apply__lead">
            {{
              'plans.learn.bulk_apply.lead'
                | translate: { count: bulkApplicableCount }
            }}
          </p>
          @if (applyErrorKey) {
            <p class="learn-bulk-apply__error" role="alert">
              {{ applyErrorKey | translate }}
            </p>
          }
          <button
            type="button"
            class="btn-primary learn-bulk-apply__cta"
            [disabled]="applying"
            (click)="onBulkApply()"
          >
            {{
              applying
                ? ('common.loading' | translate)
                : ('plans.learn.bulk_apply.cta' | translate: { count: bulkApplicableCount })
            }}
          </button>
        }
        @if (showStartPipelineCta) {
          <p class="learn-bulk-apply__pipeline-lead">
            {{ 'plans.learn.bulk_apply.pipeline_lead' | translate }}
          </p>
          <a
            class="btn-primary learn-bulk-apply__pipeline-cta"
            [routerLink]="pipelineNavigation.commands"
            [queryParams]="pipelineNavigation.queryParams"
            (click)="onStartPipeline()"
          >
            {{ 'plans.learn.bulk_apply.start_pipeline' | translate }}
          </a>
        }
      </section>
    }
  `,
  styleUrls: ['./plan-learn-bulk-apply-panel.component.css']
})
export class PlanLearnBulkApplyPanelComponent {
  private readonly bulkApplyUseCase = inject(BulkApplySafeLearnProposalsUseCase);
  private readonly cdr = inject(ChangeDetectorRef);

  @Input({ required: true }) planId!: number;
  @Input() stageGddProposals: StageGddCalibrationProposal[] = [];
  @Input() blueprintTimingProposals: BlueprintTimingAdjustmentProposal[] = [];
  @Input() progressRefreshVersion = 0;
  @Output() progressChanged = new EventEmitter<void>();

  applying = false;
  applyErrorKey: string | null = null;
  bulkApplyCompleted = false;

  get bulkApplicableCount(): number {
    void this.progressRefreshVersion;
    return countBulkApplicableLearnProposals(
      this.planId,
      this.stageGddProposals,
      this.blueprintTimingProposals
    );
  }

  get showStartPipelineCta(): boolean {
    void this.progressRefreshVersion;
    return (
      this.bulkApplyCompleted ||
      (this.bulkApplicableCount === 0 &&
        hasConfirmedLearnProposalsWithoutDismissed(
          this.planId,
          this.stageGddProposals,
          this.blueprintTimingProposals
        ))
    );
  }

  get pipelineNavigation(): ReturnType<typeof buildLearnOrchestrationPipelineStartNavigation> {
    return buildLearnOrchestrationPipelineStartNavigation(this.planId);
  }

  onBulkApply(): void {
    if (this.applying || this.bulkApplicableCount === 0) {
      return;
    }
    this.applying = true;
    this.applyErrorKey = null;

    this.bulkApplyUseCase.execute({
      planId: this.planId,
      stageGddProposals: this.stageGddProposals,
      blueprintTimingProposals: this.blueprintTimingProposals,
      onSuccess: () => {
        this.applying = false;
        this.bulkApplyCompleted = true;
        this.progressChanged.emit();
        this.cdr.markForCheck();
      },
      onError: (message) => {
        this.applying = false;
        this.applyErrorKey = message;
        this.cdr.markForCheck();
      }
    });
  }

  onStartPipeline(): void {
    storeLearnOrchestrationPipelineActive(this.planId);
  }
}
