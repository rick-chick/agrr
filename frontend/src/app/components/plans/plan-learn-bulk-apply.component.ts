import { Component, EventEmitter, Input, OnChanges, Output, SimpleChanges, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import { countSafeLearnProposals } from '../../domain/plans/is-safe-learn-proposal';
import { buildPlanDetailAdjustNavigation } from '../../domain/plans/learn-master-update-orchestration';
import { enableLearnOrchestrationAutoChain } from '../../domain/plans/learn-orchestration-auto-chain';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import { BulkApplySafeLearnProposalsUseCase } from '../../usecase/plans/bulk-apply-safe-learn-proposals.usecase';
import { LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS } from '../../usecase/plans/learn-proposal-inline-apply.providers';

@Component({
  selector: 'app-plan-learn-bulk-apply',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  providers: [...LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS, BulkApplySafeLearnProposalsUseCase],
  template: `
    @if (safeProposalCount > 0 || bulkApplyComplete) {
      <section class="plan-learn-bulk-apply" aria-labelledby="plan-learn-bulk-apply-heading">
        <h3 id="plan-learn-bulk-apply-heading" class="plan-learn-bulk-apply__title">
          {{ 'plans.learn.bulk_apply.title' | translate }}
        </h3>
        @if (!bulkApplyComplete) {
          <p class="plan-learn-bulk-apply__lead">
            {{
              'plans.learn.bulk_apply.lead'
                | translate: { count: safeProposalCount }
            }}
          </p>
          @if (applyError) {
            <p class="plan-learn-bulk-apply__error" role="alert">
              {{ applyError | translate }}
            </p>
          }
          <button
            type="button"
            class="btn-primary plan-learn-bulk-apply__cta"
            [disabled]="applying"
            (click)="onBulkApply()"
          >
            {{
              applying
                ? ('plans.learn.bulk_apply.applying' | translate)
                : ('plans.learn.bulk_apply.cta' | translate: { count: safeProposalCount })
            }}
          </button>
        } @else {
          <p class="plan-learn-bulk-apply__success">
            {{ 'plans.learn.bulk_apply.success' | translate: { count: appliedCount } }}
          </p>
          <a
            class="btn-primary plan-learn-bulk-apply__pipeline-cta"
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
  styleUrls: ['./plan-learn-bulk-apply.component.css']
})
export class PlanLearnBulkApplyComponent implements OnChanges {
  private readonly bulkApplyUseCase = inject(BulkApplySafeLearnProposalsUseCase);

  @Input({ required: true }) planId!: number;
  @Input() stageGddProposals: StageGddCalibrationProposal[] = [];
  @Input() blueprintTimingProposals: BlueprintTimingAdjustmentProposal[] = [];
  @Input() progressRefreshVersion = 0;
  @Output() progressChanged = new EventEmitter<void>();

  applying = false;
  bulkApplyComplete = false;
  appliedCount = 0;
  applyError: string | null = null;
  safeProposalCount = 0;

  ngOnChanges(_changes: SimpleChanges): void {
    this.safeProposalCount = countSafeLearnProposals(
      this.planId,
      this.stageGddProposals,
      this.blueprintTimingProposals
    );
  }

  get pipelineNavigation(): ReturnType<typeof buildPlanDetailAdjustNavigation> {
    return buildPlanDetailAdjustNavigation(this.planId);
  }

  onBulkApply(): void {
    if (this.applying || this.safeProposalCount === 0) {
      return;
    }
    this.applying = true;
    this.applyError = null;

    void this.bulkApplyUseCase
      .execute({
        planId: this.planId,
        stageGddProposals: this.stageGddProposals,
        blueprintTimingProposals: this.blueprintTimingProposals,
        onComplete: (result) => {
          this.applying = false;
          this.appliedCount = result.appliedCount;
          this.bulkApplyComplete = true;
          this.safeProposalCount = 0;
          this.progressChanged.emit();
        },
        onError: (message) => {
          this.applying = false;
          this.applyError = message;
          this.progressChanged.emit();
        }
      })
      .catch(() => {
        this.applying = false;
        this.applyError = 'common.error';
      });
  }

  onStartPipeline(): void {
    enableLearnOrchestrationAutoChain(this.planId);
  }
}
