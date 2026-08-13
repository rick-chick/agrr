import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';

@Component({
  selector: 'app-variance-action-banner',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    @if (items.length) {
      <div class="variance-action-banner" role="status" aria-live="polite">
        <p>{{ 'plans.show.variance_action_banner.message' | translate: { count: items.length } }}</p>
        <p class="variance-action-banner__hint">
          {{ 'plans.show.variance_action_banner.manual_hint' | translate }}
        </p>
        <a
          class="variance-action-banner__link"
          [routerLink]="['/plans', planId, 'learn']"
        >
          {{ 'plans.show.variance_action_banner.review_link' | translate }}
        </a>
      </div>
    }
  `,
  styleUrls: ['./variance-action-banner.component.css']
})
export class VarianceActionBannerComponent {
  @Input({ required: true }) planId!: number;
  @Input() items: PlanVarianceActionItem[] = [];
}
