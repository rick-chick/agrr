import { CommonModule } from '@angular/common';
import { ChangeDetectorRef, Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import {
  buildUnifiedLearnProposalQueue,
  groupUnifiedLearnProposalQueueByCategory,
  type LearnProposalQueueCategory,
  type UnifiedLearnProposalQueueItem
} from '../../domain/plans/build-unified-learn-proposal-queue';
import type { LearnPostMasterPayload } from '../../domain/plans/learn-proposal-application-progress';
import {
  buildLearnReorganizePipelineStartNavigation,
  storeLearnReorganizePipelineAutoChain
} from '../../domain/plans/learn-reorganize-pipeline-auto-chain';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import { BulkApplySafeLearnProposalsUseCase } from '../../usecase/plans/bulk-apply-safe-learn-proposals.usecase';
import { LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS } from '../../usecase/plans/learn-proposal-inline-apply.providers';
import {
  buildLearnApplicationProgressItems,
  PlanLearnApplicationProgressViewComponent
} from './plan-learn-application-progress-view.component';
import { PlanLearnPostMasterConfirmationComponent } from './plan-learn-post-master-confirmation.component';

@Component({
  selector: 'app-plan-learn-proposal-queue',
  standalone: true,
  imports: [
    CommonModule,
    TranslateModule,
    PlanLearnPostMasterConfirmationComponent,
    PlanLearnApplicationProgressViewComponent
  ],
  providers: [BulkApplySafeLearnProposalsUseCase, ...LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS],
  template: `
    @if (hasQueueContent) {
      <section
        class="learn-proposal-queue"
        aria-labelledby="learn-proposal-queue-heading"
      >
        <h3 id="learn-proposal-queue-heading" class="learn-proposal-queue__title">
          {{ 'plans.learn.proposal_queue.title' | translate }}
        </h3>
        <p class="learn-proposal-queue__lead">
          {{ 'plans.learn.proposal_queue.lead' | translate }}
        </p>

        @if (postMasterPayload) {
          <app-plan-learn-post-master-confirmation
            [planId]="planId"
            [payload]="postMasterPayload"
          />
        }

        @if (bulkApplyComplete) {
          <div class="learn-proposal-queue__post-apply" role="status">
            <h4 class="learn-proposal-queue__post-apply-title">
              {{ 'plans.learn.proposal_queue.post_apply.title' | translate }}
            </h4>
            <p class="learn-proposal-queue__post-apply-lead">
              {{
                'plans.learn.bulk_apply.complete_message'
                  | translate: { count: lastAppliedCount }
              }}
            </p>
            <button type="button" class="btn btn-primary" (click)="startReorganizePipeline()">
              {{ 'plans.learn.bulk_apply.start_pipeline' | translate }}
            </button>
          </div>
        }

        @for (category of categoryOrder; track category) {
          @if (groupedItems[category].length) {
            <div
              class="learn-proposal-queue__category"
              [attr.data-testid]="'queue-category-' + category"
            >
              <h4 class="learn-proposal-queue__category-title">
                {{ categoryLabel(category) | translate }}
                <span
                  class="learn-proposal-queue__category-count"
                  [attr.data-testid]="'queue-count-' + category"
                >
                  ({{ groupedItems[category].length }})
                </span>
              </h4>
              <ul class="learn-proposal-queue__list" role="list">
                @for (item of groupedItems[category]; track item.id) {
                  <li class="learn-proposal-queue__item">
                    <span class="learn-proposal-queue__item-title">{{ item.title }}</span>
                    @if (item.subtitle) {
                      <span class="learn-proposal-queue__item-subtitle">{{ item.subtitle }}</span>
                    }
                  </li>
                }
              </ul>
            </div>
          }
        }

        @if (safeCount > 0 && !bulkApplyComplete) {
          <div class="learn-proposal-queue__bulk-apply learn-bulk-apply">
            <p class="learn-bulk-apply__lead">
              {{
                'plans.learn.bulk_apply.lead'
                  | translate: { count: safeCount }
              }}
            </p>
            <div class="learn-bulk-apply__actions">
              <button
                type="button"
                class="btn btn-primary"
                [disabled]="applying"
                (click)="applyAllSafe()"
              >
                {{
                  applying
                    ? ('plans.learn.bulk_apply.applying' | translate: { applied: applyProgress.applied, total: applyProgress.total })
                    : ('plans.learn.bulk_apply.apply_button' | translate: { count: safeCount })
                }}
              </button>
            </div>
            @if (applyError) {
              <p class="learn-bulk-apply__error" role="alert">{{ applyError | translate }}</p>
            }
          </div>
        }

        <app-plan-learn-application-progress-view
          [planId]="planId"
          [stageGddProposals]="stageGddProposals"
          [blueprintTimingProposals]="blueprintTimingProposals"
          [progressRefreshVersion]="progressRefreshVersion"
        />
      </section>
    }
  `,
  styleUrls: ['./plan-learn-proposal-queue.component.css']
})
export class PlanLearnProposalQueueComponent {
  private readonly bulkApplyUseCase = inject(BulkApplySafeLearnProposalsUseCase);
  private readonly router = inject(Router);
  private readonly cdr = inject(ChangeDetectorRef);

  readonly categoryOrder: LearnProposalQueueCategory[] = [
    'requires_action',
    'requires_confirmation',
    'safe'
  ];

  @Input({ required: true }) planId!: number;
  @Input() stageGddProposals: StageGddCalibrationProposal[] = [];
  @Input() blueprintTimingProposals: BlueprintTimingAdjustmentProposal[] = [];
  @Input() actionRequiredItems: PlanVarianceActionItem[] = [];
  @Input() postMasterPayload: LearnPostMasterPayload | null = null;
  @Input() progressRefreshVersion = 0;
  @Output() progressChanged = new EventEmitter<void>();

  applying = false;
  applyError: string | null = null;
  bulkApplyComplete = false;
  lastAppliedCount = 0;
  applyProgress = { applied: 0, total: 0 };

  get queue() {
    void this.progressRefreshVersion;
    return buildUnifiedLearnProposalQueue(
      this.planId,
      this.stageGddProposals,
      this.blueprintTimingProposals,
      this.actionRequiredItems
    );
  }

  get groupedItems(): Record<LearnProposalQueueCategory, UnifiedLearnProposalQueueItem[]> {
    return groupUnifiedLearnProposalQueueByCategory(this.queue);
  }

  get safeCount(): number {
    return this.queue.counts.safe;
  }

  get hasQueueContent(): boolean {
    return (
      this.queue.items.length > 0 ||
      this.postMasterPayload != null ||
      this.applicationProgressCount > 0 ||
      this.bulkApplyComplete
    );
  }

  get applicationProgressCount(): number {
    void this.progressRefreshVersion;
    return buildLearnApplicationProgressItems(
      this.planId,
      this.stageGddProposals,
      this.blueprintTimingProposals
    ).filter((item) => item.status !== 'not_started').length;
  }

  categoryLabel(category: LearnProposalQueueCategory): string {
    return `plans.learn.proposal_queue.category.${category}`;
  }

  applyAllSafe(): void {
    if (this.applying || this.safeCount === 0) {
      return;
    }
    this.applying = true;
    this.applyError = null;
    this.applyProgress = { applied: 0, total: this.safeCount };
    this.cdr.markForCheck();

    this.bulkApplyUseCase.execute({
      planId: this.planId,
      stageGddProposals: this.stageGddProposals,
      blueprintTimingProposals: this.blueprintTimingProposals,
      onProgress: (progress) => {
        this.applyProgress = progress;
        this.cdr.markForCheck();
      },
      onSuccess: (result) => {
        this.applying = false;
        this.lastAppliedCount = result.appliedCount;
        this.bulkApplyComplete = result.appliedCount > 0;
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

  startReorganizePipeline(): void {
    storeLearnReorganizePipelineAutoChain(this.planId);
    const navigation = buildLearnReorganizePipelineStartNavigation(this.planId);
    void this.router.navigate(navigation.commands, { queryParams: navigation.queryParams });
  }
}
