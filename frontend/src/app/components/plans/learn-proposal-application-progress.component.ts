import { Component, Input, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import type { LearnProposalProgressItem } from '../../domain/plans/learn-proposal-application-progress';

@Component({
  selector: 'app-learn-proposal-application-progress',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
  @if (items.length > 0) {
    <section
      class="learn-proposal-progress"
      aria-labelledby="learn-proposal-progress-heading"
    >
      <h3 id="learn-proposal-progress-heading" class="learn-proposal-progress__title">
        {{ 'plans.learn.application_progress.title' | translate }}
      </h3>
      <p class="learn-proposal-progress__lead">
        {{ 'plans.learn.application_progress.lead' | translate }}
      </p>
      <ul class="learn-proposal-progress__list">
        @for (item of items; track item.key) {
          <li class="learn-proposal-progress__item">
            <div class="learn-proposal-progress__summary">
              <p class="learn-proposal-progress__name">
                {{ item.cropName }} — {{ displayDetail(item) }}
              </p>
              <p
                class="learn-proposal-progress__status"
                [class.learn-proposal-progress__status--pending]="
                  item.status === 'applied_pending_confirmation'
                "
              >
                {{ statusLabel(item) | translate }}
              </p>
            </div>
          </li>
        }
      </ul>
    </section>
  }
  `,
  styleUrls: ['./learn-proposal-application-progress.component.css']
})
export class LearnProposalApplicationProgressComponent {
  private readonly translate = inject(TranslateService);

  @Input({ required: true }) planId!: number;
  @Input() items: LearnProposalProgressItem[] = [];

  displayDetail(item: LearnProposalProgressItem): string {
    if (item.kind === 'bp_timing') {
      return this.translate.instant(
        `plans.learn.bp_timing_adjustment.category.${item.detailLabel}`
      );
    }
    return item.detailLabel;
  }

  statusLabel(item: LearnProposalProgressItem): string {
    return item.status === 'applied_pending_confirmation'
      ? 'plans.learn.application_progress.status.applied_pending_confirmation'
      : 'plans.learn.application_progress.status.not_started';
  }
}
