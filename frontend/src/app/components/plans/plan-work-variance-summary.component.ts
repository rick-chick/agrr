import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { PlanWorkVarianceSummaryStats } from '../../domain/plans/build-plan-work-variance-summary-stats';

@Component({
  selector: 'app-plan-work-variance-summary',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    <div class="plan-work-variance-summary" role="status" aria-live="polite">
      @if (loading) {
        <span>{{ 'common.loading' | translate }}</span>
      } @else if (error) {
        <span>{{ error | translate }}</span>
      } @else if (stats) {
        <p class="plan-work-variance-summary__line">
          {{
            'plans.work.variance.summary_line'
              | translate
                : {
                    unrecorded: stats.unrecordedCount,
                    threshold: stats.thresholdExceedanceCount,
                    gddDelay: stats.gddDelayCount
                  }
          }}
        </p>
        <a class="plan-work-variance-summary__cta" [routerLink]="['/plans', planId, 'learn']">
          {{ 'plans.work.variance.learn_cta' | translate }}
        </a>
      }
    </div>
  `,
  styleUrls: ['./plan-work-variance-summary.component.css']
})
export class PlanWorkVarianceSummaryComponent {
  @Input({ required: true }) planId!: number;
  @Input() loading = false;
  @Input() error: string | null = null;
  @Input() stats: PlanWorkVarianceSummaryStats | null = null;
}
