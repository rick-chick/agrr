import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

export interface PlanLearnInputGapSummaryStats {
  unrecordedCount: number;
  actionRequiredCount: number;
}

@Component({
  selector: 'app-plan-learn-input-gap-summary',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
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
      } @else if (stats) {
        <dl class="plan-learn-input-gap-summary__grid">
          <div>
            <dt>{{ 'plans.learn.input_gap.unrecorded' | translate }}</dt>
            <dd>{{ stats.unrecordedCount }}</dd>
          </div>
          <div>
            <dt>{{ 'plans.learn.input_gap.action_required' | translate }}</dt>
            <dd>{{ stats.actionRequiredCount }}</dd>
          </div>
        </dl>
        @if (stats.unrecordedCount > 0) {
          <a
            class="plan-learn-input-gap-summary__work-link"
            [routerLink]="['/plans', planId, 'work']"
            [queryParams]="focusItemId != null ? { task_schedule_item_id: focusItemId } : null"
          >
            {{ 'plans.learn.input_gap.work_cta' | translate }}
          </a>
        }
      }
    </section>
  `,
  styleUrls: ['./plan-learn-input-gap-summary.component.css']
})
export class PlanLearnInputGapSummaryComponent {
  @Input({ required: true }) planId!: number;
  @Input() stats: PlanLearnInputGapSummaryStats | null = null;
  @Input() loading = false;
  @Input() error: string | null = null;
  @Input() focusItemId: number | null = null;
}
