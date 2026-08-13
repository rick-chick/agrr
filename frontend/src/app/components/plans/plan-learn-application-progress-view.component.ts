import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import {
  bpTimingProposalProgressKey,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey,
  type LearnProposalApplicationStatus,
  type LearnProposalKind
} from '../../domain/plans/learn-proposal-application-progress';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';

export interface LearnApplicationProgressItem {
  key: string;
  kind: LearnProposalKind;
  title: string;
  status: LearnProposalApplicationStatus;
}

@Component({
  selector: 'app-plan-learn-application-progress-view',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    @if (items.length) {
      <section
        class="learn-application-progress"
        aria-labelledby="learn-application-progress-heading"
      >
        <h3 id="learn-application-progress-heading" class="learn-application-progress__title">
          {{ 'plans.learn.application_progress.title' | translate }}
        </h3>
        <p class="learn-application-progress__lead">
          {{ 'plans.learn.application_progress.lead' | translate }}
        </p>
        <ul class="learn-application-progress__list" role="list">
          @for (item of items; track item.key) {
            <li class="learn-application-progress__item">
              <div class="learn-application-progress__item-main">
                <span class="learn-application-progress__item-kind">{{
                  kindLabel(item.kind) | translate
                }}</span>
                <span class="learn-application-progress__item-title">{{ item.title }}</span>
              </div>
              <span
                class="learn-application-progress__status"
                [class.learn-application-progress__status--pending]="
                  item.status === 'applied_pending_confirmation'
                "
                [class.learn-application-progress__status--confirmed]="
                  item.status === 'confirmed'
                "
                [class.learn-application-progress__status--done]="item.status === 'done'"
              >
                {{ statusLabel(item.status) | translate }}
              </span>
            </li>
          }
        </ul>
      </section>
    }
  `,
  styleUrls: ['./plan-learn-application-progress-view.component.css']
})
export class PlanLearnApplicationProgressViewComponent {
  @Input({ required: true }) planId!: number;
  @Input() stageGddProposals: StageGddCalibrationProposal[] = [];
  @Input() blueprintTimingProposals: BlueprintTimingAdjustmentProposal[] = [];

  get items(): LearnApplicationProgressItem[] {
    return buildLearnApplicationProgressItems(
      this.planId,
      this.stageGddProposals,
      this.blueprintTimingProposals
    );
  }

  kindLabel(kind: LearnProposalKind): string {
    return `plans.learn.application_progress.kind.${kind}`;
  }

  statusLabel(status: LearnProposalApplicationStatus): string {
    return `plans.learn.application_progress.status.${status}`;
  }
}

export function buildLearnApplicationProgressItems(
  planId: number,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): LearnApplicationProgressItem[] {
  const items: LearnApplicationProgressItem[] = [];

  for (const proposal of stageGddProposals) {
    const key = stageGddProposalProgressKey(proposal.cropId, proposal.stageId);
    items.push({
      key,
      kind: 'stage_gdd',
      title: `${proposal.cropName} — ${proposal.stageName}`,
      status: resolveLearnProposalApplicationStatus(planId, key)
    });
  }

  for (const proposal of blueprintTimingProposals) {
    const key = bpTimingProposalProgressKey(proposal.cropId, proposal.category);
    items.push({
      key,
      kind: 'bp_timing',
      title: `${proposal.cropName} — ${proposal.category}`,
      status: resolveLearnProposalApplicationStatus(planId, key)
    });
  }

  return items;
}
