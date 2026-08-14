import { Component, Input } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import type { LearnProposalConfidence } from '../../domain/plans/resolve-learn-proposal-confidence';

@Component({
  selector: 'app-learn-proposal-confidence-badge',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <span
      class="learn-proposal-confidence"
      [class.learn-proposal-confidence--high]="confidence === 'high'"
      [class.learn-proposal-confidence--medium]="confidence === 'medium'"
      [class.learn-proposal-confidence--low]="confidence === 'low'"
    >
      {{ labelKey | translate }}
    </span>
  `,
  styleUrls: ['./learn-proposal-confidence-badge.component.css']
})
export class LearnProposalConfidenceBadgeComponent {
  @Input({ required: true }) confidence!: LearnProposalConfidence;

  get labelKey(): string {
    return `plans.learn.proposal_confidence.${this.confidence}`;
  }
}
