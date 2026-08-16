import { Component, EventEmitter, Input, Output } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  buildPlanNewCarryoverFromNavigation,
  PLAN_CARRYOVER_NEXT_PLAN_CTA_KEY
} from '../../domain/plans/plan-carryover-navigation';
import type { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { PlanCarryoverPreviewComponent } from './plan-carryover-preview.component';

@Component({
  selector: 'app-plan-learn-carryover-section',
  standalone: true,
  imports: [FormsModule, RouterLink, TranslateModule, PlanCarryoverPreviewComponent],
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
              <app-plan-carryover-preview [summary]="carryoverPreview" />
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
            }
          }
        </div>
      }

      <div class="plan-learn-carryover__next-plan" aria-labelledby="plan-learn-carryover-next-plan-title">
        <h4 id="plan-learn-carryover-next-plan-title" class="plan-learn-carryover__next-plan-title">
          {{ 'plans.carryover.next_plan_heading' | translate }}
        </h4>
        @if (sourcePlanName) {
          <p class="plan-learn-carryover__source-plan">
            {{ 'plans.learn.loop.handoff_source_plan' | translate: { planName: sourcePlanName } }}
          </p>
        }
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
  @Input() sourcePlanName: string | null = null;
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

  get nextPlanNavigation(): ReturnType<typeof buildPlanNewCarryoverFromNavigation> {
    return buildPlanNewCarryoverFromNavigation(this.planId);
  }

  onSourcePlanChange(planId: number | null): void {
    this.sourcePlanChange.emit(planId);
  }

  onImportLearning(): void {
    this.importLearning.emit();
  }
}
