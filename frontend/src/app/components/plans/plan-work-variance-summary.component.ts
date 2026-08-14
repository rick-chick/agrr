import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { PlanWorkVarianceSummaryStats } from '../../domain/plans/build-plan-work-variance-summary-stats';

@Component({
  selector: 'app-plan-work-variance-summary',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    <section
      class="plan-work-variance-summary"
      role="status"
      aria-labelledby="plan-work-variance-summary-title"
    >
      <h2 id="plan-work-variance-summary-title" class="plan-work-variance-summary__title">
        {{ 'plans.work.variance_summary.title' | translate }}
      </h2>

      @if (loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (error) {
        <div class="page-alert-error" role="alert">
          <p>{{ error | translate }}</p>
        </div>
      } @else if (stats) {
        <dl class="plan-work-variance-summary__grid">
          <div>
            <dt>{{ 'plans.work.variance_summary.unrecorded' | translate }}</dt>
            <dd>{{ stats.unrecordedCount }}</dd>
          </div>
          <div>
            <dt>{{ 'plans.work.variance_summary.threshold_exceeded' | translate }}</dt>
            <dd>{{ stats.thresholdExceededCount }}</dd>
          </div>
          <div>
            <dt>{{ 'plans.work.variance_summary.gdd_delay' | translate }}</dt>
            <dd>{{ stats.gddDelayCount }}</dd>
          </div>
        </dl>
        <a
          class="plan-work-variance-summary__learn-link"
          [routerLink]="['/plans', planId, 'learn']"
        >
          {{ 'plans.work.variance_summary.learn_cta' | translate }}
        </a>
      }
    </section>
  `,
  styleUrls: ['./plan-work-variance-summary.component.css']
})
export class PlanWorkVarianceSummaryComponent {
  @Input({ required: true }) planId!: number;
  @Input() stats: PlanWorkVarianceSummaryStats | null = null;
  @Input() loading = false;
  @Input() error: string | null = null;
}
