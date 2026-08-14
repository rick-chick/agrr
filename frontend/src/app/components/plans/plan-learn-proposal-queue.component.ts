import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { buildLearnProposalQueue } from '../../domain/plans/build-learn-proposal-queue';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import { PlanLearnBulkApplyPanelComponent } from './plan-learn-bulk-apply-panel.component';

@Component({
  selector: 'app-plan-learn-proposal-queue',
  standalone: true,
  imports: [CommonModule, TranslateModule, PlanLearnBulkApplyPanelComponent],
  template: `
    @if (queue.totalCount > 0) {
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

        @for (tier of visibleTiers; track tier) {
          @if (queue.tiers[tier].length) {
            <div
              class="learn-proposal-queue__tier"
              [attr.data-queue-tier]="tier"
            >
              <h4 class="learn-proposal-queue__tier-title">
                {{ tierLabel(tier) | translate }}
                <span class="learn-proposal-queue__tier-count">({{ queue.tiers[tier].length }})</span>
              </h4>
              <ul class="learn-proposal-queue__list" role="list">
                @for (item of queue.tiers[tier]; track item.key) {
                  <li class="learn-proposal-queue__item">
                    <span class="learn-proposal-queue__item-kind">{{
                      kindLabel(item.kind) | translate
                    }}</span>
                    <span class="learn-proposal-queue__item-title">{{ item.title }}</span>
                  </li>
                }
              </ul>
            </div>
          }
        }

        <app-plan-learn-bulk-apply-panel
          [planId]="planId"
          [stageGddProposals]="stageGddProposals"
          [blueprintTimingProposals]="blueprintTimingProposals"
          [progressRefreshVersion]="progressRefreshVersion"
          (progressChanged)="progressChanged.emit()"
          (bulkApplyConfirmed)="bulkApplyConfirmed.emit($event)"
        />
      </section>
    }
  `,
  styleUrls: ['./plan-learn-proposal-queue.component.css']
})
export class PlanLearnProposalQueueComponent {
  @Input({ required: true }) planId!: number;
  @Input() stageGddProposals: StageGddCalibrationProposal[] = [];
  @Input() blueprintTimingProposals: BlueprintTimingAdjustmentProposal[] = [];
  @Input() actionRequiredItems: PlanVarianceActionItem[] = [];
  @Input() progressRefreshVersion = 0;

  readonly visibleTiers = ['action_required', 'needs_review', 'safe'] as const;

  @Output() progressChanged = new EventEmitter<void>();
  @Output() bulkApplyConfirmed = new EventEmitter<{ appliedCount: number }>();

  get queue() {
    void this.progressRefreshVersion;
    return buildLearnProposalQueue(
      this.planId,
      this.stageGddProposals,
      this.blueprintTimingProposals,
      this.actionRequiredItems
    );
  }

  tierLabel(tier: (typeof this.visibleTiers)[number]): string {
    return `plans.learn.proposal_queue.tier.${tier}`;
  }

  kindLabel(kind: string): string {
    if (kind === 'variance_action') {
      return 'plans.learn.proposal_queue.kind.variance_action';
    }
    return `plans.learn.application_progress.kind.${kind}`;
  }
}
