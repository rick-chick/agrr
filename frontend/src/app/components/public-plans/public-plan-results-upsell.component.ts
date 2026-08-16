import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  PUBLIC_PLAN_PRIVATE_VALUE_ITEMS,
  PUBLIC_PLAN_SAVE_NEXT_STEPS,
  buildPublicPlanSaveNextStepRoute,
  isPublicPlanSaveStepComplete,
  type PublicPlanSaveNextStepKey
} from '../../domain/public-plans/public-plan-results-upsell.content';

@Component({
  selector: 'app-public-plan-results-upsell',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    <section class="public-plan-results-upsell" aria-labelledby="public-plan-results-upsell-heading">
      <div class="public-plan-results-upsell__preview">
        <div class="public-plan-results-upsell__preview-header">
          <h2 id="public-plan-results-upsell-heading" class="public-plan-results-upsell__title">
            {{ 'public_plans.results.private_value_preview.title' | translate }}
          </h2>
          <p class="public-plan-results-upsell__lead">
            {{ 'public_plans.results.private_value_preview.lead' | translate }}
          </p>
          <span class="public-plan-results-upsell__badge">
            {{ 'public_plans.results.private_value_preview.badge' | translate }}
          </span>
        </div>
        <div class="public-plan-results-upsell__preview-grid">
          @for (item of privateValueItems; track item.titleKey) {
            <article class="public-plan-results-upsell__preview-card">
              <span class="public-plan-results-upsell__preview-icon" aria-hidden="true">{{
                item.icon
              }}</span>
              <h3 class="public-plan-results-upsell__preview-card-title">
                {{ item.titleKey | translate }}
              </h3>
              <p class="public-plan-results-upsell__preview-card-description">
                {{ item.descriptionKey | translate }}
              </p>
            </article>
          }
        </div>
      </div>

      <section
        class="public-plan-results-upsell__next-steps"
        aria-labelledby="public-plan-results-next-steps-heading"
      >
        <h3 id="public-plan-results-next-steps-heading" class="public-plan-results-upsell__next-steps-title">
          {{ 'public_plans.results.next_steps.title' | translate }}
        </h3>
        <p class="public-plan-results-upsell__next-steps-lead">
          {{ 'public_plans.results.next_steps.lead' | translate }}
        </p>
        <ol class="public-plan-results-upsell__step-list" role="list">
          @for (step of nextSteps; track step.stepKey) {
            <li
              class="public-plan-results-upsell__step"
              [class.public-plan-results-upsell__step--completed]="isStepComplete(step.stepKey)"
              [class.public-plan-results-upsell__step--current]="isCurrentStep(step.stepKey)"
            >
              <div class="public-plan-results-upsell__step-main">
                <span class="public-plan-results-upsell__step-label">{{
                  stepLabel(step.stepNumber) | translate
                }}</span>
                <span class="public-plan-results-upsell__step-title">{{ step.titleKey | translate }}</span>
                <p class="public-plan-results-upsell__step-description">
                  {{ step.descriptionKey | translate }}
                </p>
              </div>
              @if (isStepComplete(step.stepKey)) {
                <span class="public-plan-results-upsell__step-completed-badge">{{
                  'public_plans.results.next_steps.completed' | translate
                }}</span>
              } @else if (stepRoute(step.stepKey); as route) {
                <a class="btn-secondary public-plan-results-upsell__step-cta" [routerLink]="route">
                  {{ stepCtaKey(step.stepKey) | translate }}
                </a>
              } @else if (step.stepKey === 'save') {
                <span class="public-plan-results-upsell__step-hint">{{
                  'public_plans.results.next_steps.save.hint' | translate
                }}</span>
              } @else {
                <span class="public-plan-results-upsell__step-hint">{{
                  'public_plans.results.next_steps.after_save_hint' | translate
                }}</span>
              }
            </li>
          }
        </ol>
      </section>
    </section>
  `,
  styleUrls: ['./public-plan-results-upsell.component.css']
})
export class PublicPlanResultsUpsellComponent {
  @Input() savedPlanId: number | null = null;

  readonly privateValueItems = PUBLIC_PLAN_PRIVATE_VALUE_ITEMS;
  readonly nextSteps = PUBLIC_PLAN_SAVE_NEXT_STEPS;

  stepLabel(stepNumber: 1 | 2 | 3): string {
    return `public_plans.results.next_steps.step_label.${stepNumber}`;
  }

  stepCtaKey(stepKey: PublicPlanSaveNextStepKey): string {
    return `public_plans.results.next_steps.cta.${stepKey}`;
  }

  isStepComplete(stepKey: PublicPlanSaveNextStepKey): boolean {
    return isPublicPlanSaveStepComplete(stepKey, this.savedPlanId);
  }

  isCurrentStep(stepKey: PublicPlanSaveNextStepKey): boolean {
    return stepKey === 'save' && this.savedPlanId === null;
  }

  stepRoute(stepKey: PublicPlanSaveNextStepKey): (string | number)[] | null {
    return buildPublicPlanSaveNextStepRoute(stepKey, this.savedPlanId);
  }
}
