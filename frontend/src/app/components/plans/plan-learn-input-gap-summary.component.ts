import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { PlanInputGapSummary } from '../../domain/plans/build-plan-input-gap-summary';
import { buildPlanWorkDeepLinkQuery } from '../../domain/plans/build-plan-work-deep-link-query';

@Component({
  selector: 'app-plan-learn-input-gap-summary',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
  <section
    class="plan-learn-input-gap-summary"
    role="status"
    aria-labelledby="plan-learn-input-gap-summary-title"
  >
    <h2 id="plan-learn-input-gap-summary-title" class="plan-learn-input-gap-summary__title">
      {{ 'plans.learn.input_gap.title' | translate }}
    </h2>

    @if (loading) {
      <p class="master-loading">{{ 'common.loading' | translate }}</p>
    } @else if (error) {
      <div class="page-alert-error" role="alert">
        <p>{{ error | translate }}</p>
      </div>
    } @else if (summary) {
      <dl class="plan-learn-input-gap-summary__grid">
        <div>
          <dt>{{ 'plans.learn.input_gap.unrecorded' | translate }}</dt>
          <dd>{{ summary.unrecordedCount }}</dd>
        </div>
        <div>
          <dt>{{ 'plans.learn.input_gap.action_required' | translate }}</dt>
          <dd>{{ summary.actionRequiredCount }}</dd>
        </div>
        <div>
          <dt>{{ 'plans.learn.input_gap.structured_unrecorded' | translate }}</dt>
          <dd>{{ summary.structuredUnrecordedCount }}</dd>
        </div>
      </dl>

      @if (summary.unrecordedCount > 0 || summary.structuredUnrecordedCount > 0) {
        <a
          class="plan-learn-input-gap-summary__work-link"
          [routerLink]="['/plans', planId, 'work']"
          [queryParams]="workDeepLinkQuery"
        >
          {{ workCtaKey | translate }}
        </a>
      }
    }
  </section>
  `,
  styleUrls: ['./plan-learn-input-gap-summary.component.css']
})
export class PlanLearnInputGapSummaryComponent {
  @Input({ required: true }) planId!: number;
  @Input() summary: PlanInputGapSummary | null = null;
  @Input() loading = false;
  @Input() error: string | null = null;
  @Input() highlightItemId: number | null = null;

  get workDeepLinkQuery(): Record<string, number> | null {
    return buildPlanWorkDeepLinkQuery(this.highlightItemId);
  }

  get workCtaKey(): string {
    if ((this.summary?.unrecordedCount ?? 0) > 0) {
      return 'plans.learn.input_gap.work_cta';
    }
    return 'plans.learn.input_gap.structured_work_cta';
  }
}
