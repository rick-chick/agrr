import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  PLAN_CARRYOVER_NEXT_PLAN_CTA_KEY,
  PLAN_CARRYOVER_NEXT_PLAN_HINT_KEY,
  buildPlanNewCarryoverFromNavigation
} from '../../domain/plans/plan-carryover-handoff';
import type { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVsActualCategorySummary, PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { formatPlanTaskScheduleAverageDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';

@Component({
  selector: 'app-plan-learn-carryover-section',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule],
  template: `
    <div class="plan-learn-carryover" aria-labelledby="plan-learn-carryover-title">
      <h3 id="plan-learn-carryover-title" class="plan-learn-carryover__title">
        {{ 'plans.carryover.section_title' | translate }}
      </h3>

      @if (showNextPlanCta) {
        <div class="plan-learn-carryover__next-plan">
          <h4 class="plan-learn-carryover__subsection-title">
            {{ nextPlanCtaKey | translate }}
          </h4>
          <p class="plan-learn-carryover__hint">{{ nextPlanHintKey | translate }}</p>
          <a
            class="btn btn-primary plan-learn-carryover__next-plan-cta"
            [routerLink]="nextPlanNavigation.routerLink"
            [queryParams]="nextPlanNavigation.queryParams"
          >
            {{ nextPlanCtaKey | translate }}
          </a>
        </div>
      }

      <div class="plan-learn-carryover__import">
        <h4 class="plan-learn-carryover__subsection-title">
          {{ 'plans.carryover.import_title' | translate }}
        </h4>
        <p class="plan-learn-carryover__hint">{{ 'plans.carryover.import_hint' | translate }}</p>
        @if (carryoverSourcePlans.length === 0) {
          <p class="plan-learn-carryover__hint">{{ 'plans.carryover.no_source_plans' | translate }}</p>
        } @else {
          <div class="plan-learn-carryover__form">
            <label for="plan-learn-carryover-source" class="plan-learn-carryover__label">{{
              'plans.carryover.source_label' | translate
            }}</label>
            <select
              id="plan-learn-carryover-source"
              class="plan-learn-carryover__select"
              [disabled]="carryoverImporting"
              [ngModel]="selectedSourcePlanId"
              (ngModelChange)="sourcePlanChange.emit($event)"
            >
              <option [ngValue]="null">{{ 'plans.carryover.source_hint' | translate }}</option>
              @for (plan of carryoverSourcePlans; track plan.id) {
                <option [ngValue]="plan.id">{{ plan.name }}</option>
              }
            </select>
            @if (selectedSourcePlanId != null) {
              @if (carryoverPreviewLoading) {
                <p class="master-loading">{{ 'common.loading' | translate }}</p>
              } @else if (carryoverPreviewError) {
                <p class="plan-learn-carryover__error">{{ carryoverPreviewError }}</p>
              } @else if (carryoverPreview) {
                <div class="plan-learn-carryover-preview">
                  <h5 class="plan-learn-carryover-preview__title">{{
                    'plans.carryover.preview_title' | translate
                  }}</h5>
                  @if (carryoverPreview.categories.length) {
                    <table class="plan-learn-carryover-preview__table">
                      <thead>
                        <tr>
                          <th scope="col">{{
                            'plans.task_schedules.variance_subview.category_column' | translate
                          }}</th>
                          <th scope="col">{{
                            'plans.task_schedules.variance_subview.category_average' | translate
                          }}</th>
                        </tr>
                      </thead>
                      <tbody>
                        @for (category of carryoverPreview.categories; track category.category) {
                          <tr>
                            <td>{{ categoryLabel(category) }}</td>
                            <td>{{ categoryAverageLabel(category) }}</td>
                          </tr>
                        }
                      </tbody>
                    </table>
                  } @else {
                    <p class="plan-learn-carryover__hint">{{
                      'plans.carryover.preview_empty' | translate
                    }}</p>
                  }
                  <button
                    type="button"
                    class="btn btn-primary plan-learn-carryover__import-button"
                    [disabled]="carryoverImporting"
                    (click)="importLearning.emit()"
                  >
                    {{
                      carryoverImporting
                        ? ('common.loading' | translate)
                        : ('plans.carryover.import_button' | translate)
                    }}
                  </button>
                  @if (carryoverImportError) {
                    <p class="plan-learn-carryover__error">{{ carryoverImportError }}</p>
                  }
                </div>
              }
            }
          </div>
        }
      </div>
    </div>
  `,
  styleUrls: ['./plan-learn-carryover-section.component.css']
})
export class PlanLearnCarryoverSectionComponent {
  @Input({ required: true }) planId!: number;
  @Input() carryoverSourcePlans: PlanSummary[] = [];
  @Input() selectedSourcePlanId: number | null = null;
  @Input() carryoverPreviewLoading = false;
  @Input() carryoverPreviewError: string | null = null;
  @Input() carryoverPreview: PlanVsActualSummary | null = null;
  @Input() carryoverImporting = false;
  @Input() carryoverImportError: string | null = null;
  @Input() showNextPlanCta = false;

  @Output() readonly sourcePlanChange = new EventEmitter<number | null>();
  @Output() readonly importLearning = new EventEmitter<void>();

  readonly nextPlanCtaKey = PLAN_CARRYOVER_NEXT_PLAN_CTA_KEY;
  readonly nextPlanHintKey = PLAN_CARRYOVER_NEXT_PLAN_HINT_KEY;

  get nextPlanNavigation(): ReturnType<typeof buildPlanNewCarryoverFromNavigation> {
    return buildPlanNewCarryoverFromNavigation(this.planId);
  }

  categoryLabel(category: PlanVsActualCategorySummary): string {
    return category.category;
  }

  categoryAverageLabel(category: PlanVsActualCategorySummary): string {
    return formatPlanTaskScheduleAverageDeltaDaysLabel(category.average_delta_days);
  }
}
