import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';

@Component({
  selector: 'app-plan-learn-imported-banner',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    @if (items.length) {
      <div class="plan-learn-imported-banner" role="status" aria-live="polite">
        <p>{{ 'plans.learn.imported_banner.message' | translate: { count: items.length } }}</p>
        <p class="plan-learn-imported-banner__hint">
          {{ 'plans.learn.imported_banner.manual_hint' | translate }}
        </p>
        <a
          class="plan-learn-imported-banner__link"
          [routerLink]="['/plans', planId]"
          [queryParams]="workbenchQueryParams"
        >
          {{ 'plans.learn.imported_banner.workbench_link' | translate }}
        </a>
      </div>
    }
  `,
  styleUrls: ['./plan-learn-imported-banner.component.css']
})
export class PlanLearnImportedBannerComponent {
  @Input({ required: true }) planId!: number;
  @Input() items: PlanVarianceActionItem[] = [];

  get workbenchQueryParams(): { field_cultivation_id?: number } {
    const first = this.items[0];
    return first?.field_cultivation_id != null
      ? { field_cultivation_id: first.field_cultivation_id }
      : {};
  }
}
