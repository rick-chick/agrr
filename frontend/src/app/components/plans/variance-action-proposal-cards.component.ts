import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { formatPlanTaskScheduleDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';

@Component({
  selector: 'app-variance-action-proposal-cards',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    @if (items.length) {
      <section
        class="variance-action-proposals"
        aria-labelledby="variance-action-proposals-title"
      >
        <h3 id="variance-action-proposals-title" class="variance-action-proposals__title">
          {{ 'plans.learn.action_proposals.title' | translate }}
        </h3>
        <p class="variance-action-proposals__hint">
          {{ 'plans.learn.action_proposals.manual_hint' | translate }}
        </p>
        <ul class="variance-action-proposals__list" role="list">
          @for (item of items; track item.item_id) {
            <li class="variance-action-proposals__card">
              <div class="variance-action-proposals__card-main">
                <span class="variance-action-proposals__card-name">{{ item.name }}</span>
                <span class="variance-action-proposals__card-meta">{{
                  exceedanceLabel(item.exceedance_kind) | translate
                }}</span>
                @if (item.delta_days != null) {
                  <span class="variance-action-proposals__card-delta">{{
                    deltaLabel(item.delta_days)
                  }}</span>
                }
              </div>
              <a
                class="variance-action-proposals__cta"
                [routerLink]="['/plans', planId]"
                [queryParams]="{ field_cultivation_id: item.field_cultivation_id }"
              >
                {{ 'plans.learn.action_proposals.open_workbench' | translate }}
              </a>
            </li>
          }
        </ul>
      </section>
    }
  `,
  styleUrls: ['./variance-action-proposal-cards.component.css']
})
export class VarianceActionProposalCardsComponent {
  @Input({ required: true }) planId!: number;
  @Input() items: PlanVarianceActionItem[] = [];

  exceedanceLabel(kind: PlanVarianceActionItem['exceedance_kind']): string {
    return `plans.learn.action_proposals.exceedance.${kind}`;
  }

  deltaLabel(deltaDays: number): string {
    return formatPlanTaskScheduleDeltaDaysLabel(deltaDays);
  }
}
