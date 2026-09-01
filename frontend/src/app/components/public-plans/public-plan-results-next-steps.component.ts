import { Component, EventEmitter, Input, Output } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  PUBLIC_PLAN_SAVE_NEXT_STEPS,
  buildPublicPlanSaveNextStepRoute,
  isPublicPlanSaveStepComplete,
  isPublicPlanSaveStepCurrent,
  type PublicPlanSaveNextStep,
  type PublicPlanSaveNextStepKey
} from '../../domain/public-plans/public-plan-results-upsell.content';

@Component({
  selector: 'app-public-plan-results-next-steps',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    <section
      class="public-plan-results-next-steps"
      aria-labelledby="public-plan-results-next-steps-heading"
    >
      <h2 id="public-plan-results-next-steps-heading" class="public-plan-results-next-steps__title">
        {{ 'public_plans.results.next_steps.title' | translate }}
      </h2>
      <p class="public-plan-results-next-steps__lead">
        {{ 'public_plans.results.next_steps.lead' | translate }}
      </p>
      <ol class="public-plan-results-next-steps__list" role="list">
        @for (step of steps; track step.stepKey) {
          <li
            class="public-plan-results-next-steps__item"
            [class.public-plan-results-next-steps__item--completed]="isStepComplete(step.stepKey)"
            [class.public-plan-results-next-steps__item--current]="isStepCurrent(step.stepKey)"
          >
            <div class="public-plan-results-next-steps__item-main">
              <span class="public-plan-results-next-steps__step-label">{{
                stepLabel(step.stepNumber) | translate
              }}</span>
              <span class="public-plan-results-next-steps__step-title">{{
                step.titleKey | translate
              }}</span>
              <p class="public-plan-results-next-steps__step-description">
                {{ step.descriptionKey | translate }}
              </p>
            </div>
            @if (isStepComplete(step.stepKey)) {
              <span class="public-plan-results-next-steps__completed-badge">{{
                'public_plans.results.next_steps.completed' | translate
              }}</span>
            } @else if (stepRoute(step.stepKey); as route) {
              <a
                class="btn-secondary public-plan-results-next-steps__cta"
                [routerLink]="route"
              >
                {{ ctaKey(step.stepKey) | translate }}
              </a>
            } @else if (isStepCurrent(step.stepKey)) {
              <button
                type="button"
                class="btn-primary public-plan-results-next-steps__cta"
                (click)="saveRequest.emit()"
              >
                {{ currentStepCtaKey(step.stepKey) | translate }}
              </button>
            } @else {
              <span class="public-plan-results-next-steps__locked" aria-disabled="true">
                {{ 'public_plans.results.next_steps.after_save_hint' | translate }}
              </span>
            }
          </li>
        }
      </ol>
    </section>
  `,
  styleUrls: ['./public-plan-results-next-steps.component.css']
})
export class PublicPlanResultsNextStepsComponent {
  @Input({ required: true }) isLoggedIn!: boolean;
  @Input() savedPrivatePlanId: number | null = null;
  @Output() saveRequest = new EventEmitter<void>();

  readonly steps = PUBLIC_PLAN_SAVE_NEXT_STEPS;

  stepLabel(stepNumber: 1 | 2 | 3): string {
    return `public_plans.results.next_steps.step_label.${stepNumber}`;
  }

  ctaKey(stepKey: PublicPlanSaveNextStepKey): string {
    return `public_plans.results.next_steps.cta.${stepKey}`;
  }

  currentStepCtaKey(stepKey: PublicPlanSaveNextStepKey): string {
    if (stepKey === 'save' && !this.isLoggedIn) {
      return 'public_plans.results.next_steps.cta.login_save';
    }
    return 'public_plans.results.next_steps.cta.save';
  }

  stepRoute(stepKey: PublicPlanSaveNextStepKey): (string | number)[] | null {
    return buildPublicPlanSaveNextStepRoute(stepKey, this.savedPrivatePlanId);
  }

  isStepComplete(stepKey: PublicPlanSaveNextStepKey): boolean {
    return isPublicPlanSaveStepComplete(stepKey, this.savedPrivatePlanId);
  }

  isStepCurrent(stepKey: PublicPlanSaveNextStepKey): boolean {
    return isPublicPlanSaveStepCurrent(stepKey, this.savedPrivatePlanId);
  }
}

export type { PublicPlanSaveNextStep };
