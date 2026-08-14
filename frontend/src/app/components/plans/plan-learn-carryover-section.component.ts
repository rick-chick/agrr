import { Component, EventEmitter, Input, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import {
  buildPlanNewCarryoverFromNavigation,
  PLAN_CARRYOVER_NEXT_PLAN_CTA_KEY
} from '../../domain/plans/plan-carryover-navigation';
import type { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVsActualCategorySummary, PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { formatPlanTaskScheduleAverageDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';

@Component({
  selector: 'app-plan-learn-carryover-section',
  standalone: true,
  imports: [FormsModule, RouterLink, TranslateModule],
  template: `
    <section class="plan-learn-carryover" aria-labelledby="plan-learn-carryover-title">
      <h3 id="plan-learn-carryover-title" class="plan-learn-carryover__title">
        {{ 'plans.learn.carryover.title' | translate }}
      </h3>
      <p class="plan-learn-carryover__hint">{{ 'plans.learn.carryover.hint' | translate }}</p>

      @if (carryoverSourcePlans.length === 0) {
        <p class="plan-learn-carryover__hint">{{
          'plans.learn.carryover.no_source_plans' | translate
        }}</p>
      } @else {
        <div class="plan-learn-carryover__form">
          <label for="plan-learn-carryover-source" class="plan-learn-carryover__label">{{
            'plans.learn.carryover.source_label' | translate
          }}</label>
          <select
            id="plan-learn-carryover-source"
            class="plan-learn-carryover__select"
            [disabled]="carryoverImporting"
            [ngModel]="selectedSourcePlanId"
            (ngModelChange)="onSourcePlanChange($event)"
          >
            <option [ngValue]="null">{{ 'plans.learn.carryover.source_hint' | translate }}</option>
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
                <h4 class="plan-learn-carryover-preview__title">{{
                  'plans.learn.carryover.preview_title' | translate
                }}</h4>
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
                    'plans.learn.carryover.preview_empty' | translate
                  }}</p>
                }
                <button
                  type="button"
                  class="btn btn-primary"
                  [disabled]="carryoverImporting"
                  (click)="onImportLearning()"
                >
                  {{
                    carryoverImporting
                      ? ('common.loading' | translate)
                      : ('plans.learn.carryover.import_button' | translate)
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

      <div class="plan-learn-carryover__next-plan" aria-labelledby="plan-learn-carryover-next-plan-title">
        <h4 id="plan-learn-carryover-next-plan-title" class="plan-learn-carryover__next-plan-title">
          {{ 'plans.carryover.next_plan_heading' | translate }}
        </h4>
        <p class="plan-learn-carryover__hint">{{ 'plans.carryover.next_plan_hint' | translate }}</p>
        <a
          class="btn btn-primary plan-learn-carryover__next-plan-cta"
          [routerLink]="nextPlanNavigation.routerLink"
          [queryParams]="nextPlanNavigation.queryParams"
        >
          {{ nextPlanCtaKey | translate }}
        </a>
      </div>
    </section>
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

  @Output() readonly sourcePlanChange = new EventEmitter<number | null>();
  @Output() readonly importLearning = new EventEmitter<void>();

  readonly nextPlanCtaKey = PLAN_CARRYOVER_NEXT_PLAN_CTA_KEY;

  constructor(private readonly translate: TranslateService) {}

  get nextPlanNavigation(): ReturnType<typeof buildPlanNewCarryoverFromNavigation> {
    return buildPlanNewCarryoverFromNavigation(this.planId);
  }

  onSourcePlanChange(planId: number | null): void {
    this.sourcePlanChange.emit(planId);
  }

  onImportLearning(): void {
    this.importLearning.emit();
  }

  categoryLabel(category: PlanVsActualCategorySummary): string {
    return this.translate.instant(
      `plans.task_schedules.variance_subview.category.${category.category}`
    );
  }

  categoryAverageLabel(category: PlanVsActualCategorySummary): string {
    if (category.average_delta_days == null) {
      return this.translate.instant('plans.task_schedules.variance_subview.not_available');
    }
    return this.translate.instant('plans.task_schedules.variance_subview.average_value', {
      delta: formatPlanTaskScheduleAverageDeltaDaysLabel(category.average_delta_days)
    });
  }
}
