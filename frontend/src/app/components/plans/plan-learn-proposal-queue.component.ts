import { CommonModule } from '@angular/common';
import { ChangeDetectorRef, Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import type { BlueprintAmountAdjustmentProposal } from '../../domain/plans/blueprint-amount-adjustment-proposal';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import {
  buildFertilizerTimingQueueItems,
  buildPestControlTimingQueueItems,
  buildUnifiedLearnProposalQueue,
  groupUnifiedLearnProposalQueueExcludingDedicatedTimingSections,
  resolveBpTimingEvidenceKey,
  type LearnProposalQueueCategory,
  type UnifiedLearnProposalQueueItem
} from '../../domain/plans/build-unified-learn-proposal-queue';
import type { LearnPostMasterPayload } from '../../domain/plans/learn-proposal-application-progress';
import {
  bpTimingProposalProgressKey,
  resolveLearnProposalApplicationStatus,
  type LearnProposalApplicationStatus
} from '../../domain/plans/learn-proposal-application-progress';
import type { LearnProposalEvidence } from '../../domain/plans/learn-proposal-evidence';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import {
  findBpTimingProposalForQueueItem,
  findStageGddProposalForQueueItem
} from '../../domain/plans/resolve-learn-queue-item-inline-apply';
import { BulkApplySafeLearnProposalsUseCase } from '../../usecase/plans/bulk-apply-safe-learn-proposals.usecase';
import { StartLearnVarianceLearningReoptimizeUseCase } from '../../usecase/plans/start-learn-variance-learning-reoptimize.usecase';
import { LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS } from '../../usecase/plans/learn-proposal-inline-apply.providers';
import {
  buildLearnApplicationProgressItems,
  PlanLearnApplicationProgressViewComponent
} from './plan-learn-application-progress-view.component';
import { PlanLearnPostMasterConfirmationComponent } from './plan-learn-post-master-confirmation.component';
import { LearnProposalEvidencePanelComponent } from './learn-proposal-evidence-panel.component';
import { PlanLearnProposalQueueItemConfirmationComponent } from './plan-learn-proposal-queue-item-confirmation.component';

@Component({
  selector: 'app-plan-learn-proposal-queue',
  standalone: true,
  imports: [
    CommonModule,
    TranslateModule,
    PlanLearnPostMasterConfirmationComponent,
    PlanLearnApplicationProgressViewComponent,
    LearnProposalEvidencePanelComponent,
    PlanLearnProposalQueueItemConfirmationComponent
  ],
  providers: [
    BulkApplySafeLearnProposalsUseCase,
    StartLearnVarianceLearningReoptimizeUseCase,
    ...LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS
  ],
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

        @if (pipelineStartFailed) {
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
            <button type="button" class="btn btn-primary" (click)="retryReorganizePipeline()">
              {{ 'plans.learn.bulk_apply.start_pipeline' | translate }}
            </button>
          </div>
        }

        @if (fertilizerTimingItems.length) {
          <div
            class="learn-proposal-queue__fertilizer-timing"
            data-testid="fertilizer-timing-section"
          >
            <h4 class="learn-proposal-queue__fertilizer-timing-title">
              {{ 'plans.learn.proposal_queue.fertilizer_timing.title' | translate }}
            </h4>
            <p class="learn-proposal-queue__fertilizer-timing-lead">
              {{ 'plans.learn.proposal_queue.fertilizer_timing.lead' | translate }}
            </p>
            <p class="learn-proposal-queue__fertilizer-timing-source">
              {{ 'plans.learn.proposal_queue.fertilizer_timing.evidence.source' | translate }}
            </p>
            <ul class="learn-proposal-queue__list" role="list">
              @for (item of fertilizerTimingItems; track item.id) {
                <li class="learn-proposal-queue__item learn-proposal-queue__item--fertilizer">
                  <div class="learn-proposal-queue__item-header">
                    <span class="learn-proposal-queue__item-title">{{ item.title }}</span>
                    <span class="learn-proposal-queue__item-category-badge">
                      {{ bpTimingCategoryLabel(item) | translate }}
                    </span>
                    <span
                      class="learn-proposal-queue__item-status"
                      [class.learn-proposal-queue__item-status--pending]="
                        dedicatedTimingItemStatus(item) === 'applied_pending_confirmation'
                      "
                      [class.learn-proposal-queue__item-status--confirmed]="
                        dedicatedTimingItemStatus(item) === 'confirmed'
                      "
                      [class.learn-proposal-queue__item-status--done]="
                        dedicatedTimingItemStatus(item) === 'done'
                      "
                    >
                      {{ statusLabel(dedicatedTimingItemStatus(item)) | translate }}
                    </span>
                  </div>
                  @if (item.category === 'requires_confirmation') {
                    <app-plan-learn-proposal-queue-item-confirmation
                      [planId]="planId"
                      [item]="item"
                      [bpTimingProposal]="bpTimingProposalFor(item)"
                      [evidence]="dedicatedTimingEvidenceFor(item)"
                      evidenceToggleKey="plans.learn.proposal_queue.fertilizer_timing.evidence.toggle"
                      evidenceRationaleKey="plans.learn.proposal_queue.fertilizer_timing.evidence.rationale"
                      evidenceRecordsTitleKey="plans.learn.proposal_queue.fertilizer_timing.evidence.records_title"
                      evidenceRecordLabelKey="plans.learn.proposal_queue.fertilizer_timing.evidence.record"
                      (progressChanged)="onInlineConfirmationProgressChanged()"
                    />
                  } @else {
                    <app-learn-proposal-evidence-panel
                      [evidence]="dedicatedTimingEvidenceFor(item)"
                      toggleLabelKey="plans.learn.proposal_queue.fertilizer_timing.evidence.toggle"
                      rationaleKey="plans.learn.proposal_queue.fertilizer_timing.evidence.rationale"
                      recordsTitleKey="plans.learn.proposal_queue.fertilizer_timing.evidence.records_title"
                      recordLabelKey="plans.learn.proposal_queue.fertilizer_timing.evidence.record"
                    />
                  }
                </li>
              }
            </ul>
          </div>
        }

        @if (pestControlTimingItems.length) {
          <div
            class="learn-proposal-queue__pest-control-timing"
            data-testid="pest-control-timing-section"
          >
            <h4 class="learn-proposal-queue__pest-control-timing-title">
              {{ 'plans.learn.proposal_queue.pest_control_timing.title' | translate }}
            </h4>
            <p class="learn-proposal-queue__pest-control-timing-lead">
              {{ 'plans.learn.proposal_queue.pest_control_timing.lead' | translate }}
            </p>
            <p class="learn-proposal-queue__pest-control-timing-source">
              {{ 'plans.learn.proposal_queue.pest_control_timing.evidence.source' | translate }}
            </p>
            <ul class="learn-proposal-queue__list" role="list">
              @for (item of pestControlTimingItems; track item.id) {
                <li class="learn-proposal-queue__item learn-proposal-queue__item--pest-control">
                  <div class="learn-proposal-queue__item-header">
                    <span class="learn-proposal-queue__item-title">{{ item.title }}</span>
                    <span class="learn-proposal-queue__item-category-badge">
                      {{ bpTimingCategoryLabel(item) | translate }}
                    </span>
                    <span
                      class="learn-proposal-queue__item-status"
                      [class.learn-proposal-queue__item-status--pending]="
                        dedicatedTimingItemStatus(item) === 'applied_pending_confirmation'
                      "
                      [class.learn-proposal-queue__item-status--confirmed]="
                        dedicatedTimingItemStatus(item) === 'confirmed'
                      "
                      [class.learn-proposal-queue__item-status--done]="
                        dedicatedTimingItemStatus(item) === 'done'
                      "
                    >
                      {{ statusLabel(dedicatedTimingItemStatus(item)) | translate }}
                    </span>
                  </div>
                  @if (item.category === 'requires_confirmation') {
                    <app-plan-learn-proposal-queue-item-confirmation
                      [planId]="planId"
                      [item]="item"
                      [bpTimingProposal]="bpTimingProposalFor(item)"
                      [evidence]="dedicatedTimingEvidenceFor(item)"
                      evidenceToggleKey="plans.learn.proposal_queue.pest_control_timing.evidence.toggle"
                      evidenceRationaleKey="plans.learn.proposal_queue.pest_control_timing.evidence.rationale"
                      evidenceRecordsTitleKey="plans.learn.proposal_queue.pest_control_timing.evidence.records_title"
                      evidenceRecordLabelKey="plans.learn.proposal_queue.pest_control_timing.evidence.record"
                      (progressChanged)="onInlineConfirmationProgressChanged()"
                    />
                  } @else {
                    <app-learn-proposal-evidence-panel
                      [evidence]="dedicatedTimingEvidenceFor(item)"
                      toggleLabelKey="plans.learn.proposal_queue.pest_control_timing.evidence.toggle"
                      rationaleKey="plans.learn.proposal_queue.pest_control_timing.evidence.rationale"
                      recordsTitleKey="plans.learn.proposal_queue.pest_control_timing.evidence.records_title"
                      recordLabelKey="plans.learn.proposal_queue.pest_control_timing.evidence.record"
                    />
                  }
                </li>
              }
            </ul>
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
                    @if (category === 'requires_confirmation') {
                      <app-plan-learn-proposal-queue-item-confirmation
                        [planId]="planId"
                        [item]="item"
                        [stageGddProposal]="stageGddProposalFor(item)"
                        [bpTimingProposal]="bpTimingProposalFor(item)"
                        [evidence]="queueItemEvidenceFor(item)"
                        (progressChanged)="onInlineConfirmationProgressChanged()"
                      />
                    }
                  </li>
                }
              </ul>
            </div>
          }
        }

        @if (safeCount > 0 && !pipelineStartFailed) {
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
          [blueprintAmountProposals]="blueprintAmountProposals"
          [progressRefreshVersion]="progressRefreshVersion"
        />
      </section>
    }
  `,
  styleUrls: ['./plan-learn-proposal-queue.component.css']
})
export class PlanLearnProposalQueueComponent {
  private readonly bulkApplyUseCase = inject(BulkApplySafeLearnProposalsUseCase);
  private readonly reoptimizeUseCase = inject(StartLearnVarianceLearningReoptimizeUseCase);
  private readonly cdr = inject(ChangeDetectorRef);

  readonly categoryOrder: LearnProposalQueueCategory[] = [
    'requires_action',
    'requires_confirmation',
    'safe'
  ];

  @Input({ required: true }) planId!: number;
  @Input() stageGddProposals: StageGddCalibrationProposal[] = [];
  @Input() blueprintTimingProposals: BlueprintTimingAdjustmentProposal[] = [];
  @Input() blueprintAmountProposals: BlueprintAmountAdjustmentProposal[] = [];
  @Input() blueprintTimingEvidenceByKey: Record<string, LearnProposalEvidence> = {};
  @Input() actionRequiredItems: PlanVarianceActionItem[] = [];
  @Input() postMasterPayload: LearnPostMasterPayload | null = null;
  @Input() progressRefreshVersion = 0;
  @Output() progressChanged = new EventEmitter<void>();

  applying = false;
  applyError: string | null = null;
  pipelineStartFailed = false;
  lastAppliedCount = 0;
  applyProgress = { applied: 0, total: 0 };

  get queue() {
    void this.progressRefreshVersion;
    return buildUnifiedLearnProposalQueue(
      this.planId,
      this.stageGddProposals,
      this.blueprintTimingProposals,
      this.blueprintAmountProposals,
      this.actionRequiredItems
    );
  }

  get groupedItems(): Record<LearnProposalQueueCategory, UnifiedLearnProposalQueueItem[]> {
    return groupUnifiedLearnProposalQueueExcludingDedicatedTimingSections(this.queue);
  }

  get fertilizerTimingItems(): UnifiedLearnProposalQueueItem[] {
    return buildFertilizerTimingQueueItems(this.planId, this.blueprintTimingProposals);
  }

  get pestControlTimingItems(): UnifiedLearnProposalQueueItem[] {
    return buildPestControlTimingQueueItems(this.planId, this.blueprintTimingProposals);
  }

  get safeCount(): number {
    return this.queue.counts.safe;
  }

  get hasQueueContent(): boolean {
    return (
      this.queue.items.length > 0 ||
      this.fertilizerTimingItems.length > 0 ||
      this.pestControlTimingItems.length > 0 ||
      this.postMasterPayload != null ||
      this.applicationProgressCount > 0 ||
      this.pipelineStartFailed
    );
  }

  get applicationProgressCount(): number {
    void this.progressRefreshVersion;
    return buildLearnApplicationProgressItems(
      this.planId,
      this.stageGddProposals,
      this.blueprintTimingProposals,
      this.blueprintAmountProposals
    ).filter((item) => item.status !== 'not_started').length;
  }

  categoryLabel(category: LearnProposalQueueCategory): string {
    return `plans.learn.proposal_queue.category.${category}`;
  }

  bpTimingCategoryLabel(item: UnifiedLearnProposalQueueItem): string {
    return `plans.learn.bp_timing_adjustment.category.${item.bpTimingCategory ?? 'general'}`;
  }

  dedicatedTimingEvidenceFor(item: UnifiedLearnProposalQueueItem): LearnProposalEvidence | null {
    const proposal = this.blueprintTimingProposals.find(
      (candidate) => `bp_timing:${candidate.cropId}:${candidate.category}` === item.id
    );
    if (!proposal) {
      return null;
    }
    return this.blueprintTimingEvidenceByKey[resolveBpTimingEvidenceKey(proposal)] ?? null;
  }

  dedicatedTimingItemStatus(item: UnifiedLearnProposalQueueItem): LearnProposalApplicationStatus {
    void this.progressRefreshVersion;
    const proposal = this.blueprintTimingProposals.find(
      (candidate) => `bp_timing:${candidate.cropId}:${candidate.category}` === item.id
    );
    if (!proposal) {
      return 'not_started';
    }
    return resolveLearnProposalApplicationStatus(
      this.planId,
      bpTimingProposalProgressKey(proposal.cropId, proposal.category)
    );
  }

  statusLabel(status: LearnProposalApplicationStatus): string {
    return `plans.learn.application_progress.status.${status}`;
  }

  stageGddProposalFor(item: UnifiedLearnProposalQueueItem) {
    return findStageGddProposalForQueueItem(item, this.stageGddProposals);
  }

  bpTimingProposalFor(item: UnifiedLearnProposalQueueItem) {
    return findBpTimingProposalForQueueItem(item, this.blueprintTimingProposals);
  }

  queueItemEvidenceFor(item: UnifiedLearnProposalQueueItem): LearnProposalEvidence | null {
    const proposal = this.bpTimingProposalFor(item);
    if (!proposal) {
      return null;
    }
    return this.blueprintTimingEvidenceByKey[resolveBpTimingEvidenceKey(proposal)] ?? null;
  }

  onInlineConfirmationProgressChanged(): void {
    this.progressChanged.emit();
    this.cdr.markForCheck();
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
      blueprintAmountProposals: this.blueprintAmountProposals,
      onProgress: (progress) => {
        this.applyProgress = progress;
        this.cdr.markForCheck();
      },
      onSuccess: (result) => {
        this.applying = false;
        this.lastAppliedCount = result.appliedCount;
        this.progressChanged.emit();
        this.cdr.markForCheck();
        if (result.appliedCount > 0) {
          this.startReoptimizeAfterBulkApply();
        }
      },
      onError: (message) => {
        this.applying = false;
        this.applyError = message;
        this.cdr.markForCheck();
      }
    });
  }

  retryReorganizePipeline(): void {
    this.startReoptimizeAfterBulkApply();
  }

  private startReoptimizeAfterBulkApply(): void {
    this.pipelineStartFailed = false;
    this.reoptimizeUseCase.execute({
      planId: this.planId,
      onSuccess: () => {
        this.pipelineStartFailed = false;
        this.progressChanged.emit();
        this.cdr.markForCheck();
      },
      onError: () => {
        this.pipelineStartFailed = true;
        this.progressChanged.emit();
        this.cdr.markForCheck();
      }
    });
  }
}
