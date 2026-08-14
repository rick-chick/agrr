import { Component, Input } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import type { LearnProposalConfidence } from '../../domain/plans/resolve-learn-proposal-confidence';

@Component({
  selector: 'app-learn-proposal-confidence-badge',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <span
      class="learn-proposal-confidence-badge"
      [class.learn-proposal-confidence-badge--low]="confidence === 'low'"
      [class.learn-proposal-confidence-badge--medium]="confidence === 'medium'"
      [class.learn-proposal-confidence-badge--high]="confidence === 'high'"
    >
      {{ 'plans.learn.proposal_confidence.label' | translate }}:
      {{ 'plans.learn.proposal_confidence.' + confidence | translate }}
    </span>
  `,
  styleUrls: ['./learn-proposal-confidence-badge.component.css']
})
export class LearnProposalConfidenceBadgeComponent {
  @Input({ required: true }) confidence!: LearnProposalConfidence;
}
