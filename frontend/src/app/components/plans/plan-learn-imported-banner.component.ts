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
    @if (items.length || mergedProposalCount > 0) {
      <div class="plan-learn-imported-banner" role="status" aria-live="polite">
        @if (items.length) {
          <p>{{ 'plans.learn.imported_banner.message' | translate: { count: items.length } }}</p>
        }
        @if (mergedProposalCount > 0) {
          <p>{{
            'plans.learn.imported_banner.merged_proposals'
              | translate: { count: mergedProposalCount }
          }}</p>
        }
        <p class="plan-learn-imported-banner__hint">
          {{ 'plans.learn.imported_banner.manual_hint' | translate }}
        </p>
        @if (items.length) {
          <a
            class="plan-learn-imported-banner__link"
            [routerLink]="['/plans', planId]"
            [queryParams]="workbenchQueryParams"
          >
            {{ 'plans.learn.imported_banner.workbench_link' | translate }}
          </a>
        }
      </div>
    }
  `,
  styleUrls: ['./plan-learn-imported-banner.component.css']
})
export class PlanLearnImportedBannerComponent {
  @Input({ required: true }) planId!: number;
  @Input() items: PlanVarianceActionItem[] = [];
  @Input() mergedProposalCount = 0;

  get workbenchQueryParams(): { field_cultivation_id?: number } {
    const first = this.items[0];
    return first?.field_cultivation_id != null
      ? { field_cultivation_id: first.field_cultivation_id }
      : {};
  }
}
