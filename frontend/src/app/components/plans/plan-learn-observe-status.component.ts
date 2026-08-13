import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  isLearnObservePhaseComplete,
  shouldShowLearnUnrecordedCta
} from '../../domain/plans/learn-observe-phase-status';

@Component({
  selector: 'app-plan-learn-observe-status',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    @if (!varianceLoading && !varianceError) {
      @if (showUnrecordedCta) {
        <section
          class="plan-learn-observe-status plan-learn-observe-status--unrecorded"
          role="status"
          aria-live="polite"
          aria-labelledby="plan-learn-observe-unrecorded-title"
        >
          <p id="plan-learn-observe-unrecorded-title" class="plan-learn-observe-status__message">
            {{
              'plans.learn.observe.unrecorded_message'
                | translate: { count: unrecordedCount }
            }}
          </p>
          <a
            class="btn btn-primary plan-learn-observe-status__cta"
            [routerLink]="['/plans', planId, 'work']"
          >
            {{ 'plans.learn.observe.record_work_cta' | translate }}
          </a>
        </section>
      } @else if (observeComplete) {
        <section
          class="plan-learn-observe-status plan-learn-observe-status--complete"
          role="status"
          aria-live="polite"
        >
          <p class="plan-learn-observe-status__message">
            {{ 'plans.learn.observe.complete_message' | translate }}
          </p>
        </section>
      }
    }
  `,
  styleUrls: ['./plan-learn-observe-status.component.css']
})
export class PlanLearnObserveStatusComponent {
  @Input({ required: true }) planId!: number;
  @Input() varianceLoading = false;
  @Input() varianceError: string | null = null;
  @Input() unrecordedCount = 0;

  get showUnrecordedCta(): boolean {
    return shouldShowLearnUnrecordedCta({
      unrecordedCount: this.unrecordedCount,
      varianceLoaded: true
    });
  }

  get observeComplete(): boolean {
    return isLearnObservePhaseComplete({
      unrecordedCount: this.unrecordedCount,
      varianceLoaded: true
    });
  }
}
