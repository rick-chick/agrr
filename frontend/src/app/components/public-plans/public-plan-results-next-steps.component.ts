import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

export interface PublicPlanResultsNextStep {
  stepKey: 'save' | 'task_schedule' | 'work_record';
  stepNumber: 1 | 2 | 3;
  titleKey: string;
  descriptionKey: string;
  commands?: (string | number)[];
}

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
            } @else if (step.commands) {
              <a
                class="btn-secondary public-plan-results-next-steps__cta"
                [routerLink]="step.commands"
              >
                {{ ctaKey(step.stepKey) | translate }}
              </a>
            } @else if (isStepCurrent(step.stepKey)) {
              <span class="public-plan-results-next-steps__hint">{{
                currentStepHint(step.stepKey) | translate
              }}</span>
            } @else {
              <span class="public-plan-results-next-steps__hint">{{
                'public_plans.results.next_steps.after_save_hint' | translate
              }}</span>
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

  get steps(): PublicPlanResultsNextStep[] {
    return buildPublicPlanResultsNextSteps(this.savedPrivatePlanId);
  }

  stepLabel(stepNumber: 1 | 2 | 3): string {
    return `public_plans.results.next_steps.step_label.${stepNumber}`;
  }

  ctaKey(stepKey: PublicPlanResultsNextStep['stepKey']): string {
    return `public_plans.results.next_steps.cta.${stepKey}`;
  }

  currentStepHint(stepKey: PublicPlanResultsNextStep['stepKey']): string {
    if (stepKey === 'save' && !this.isLoggedIn) {
      return 'public_plans.results.next_steps.cta.login_save';
    }
    return 'public_plans.results.next_steps.cta.save';
  }

  isStepComplete(stepKey: PublicPlanResultsNextStep['stepKey']): boolean {
    if (stepKey === 'save') {
      return this.savedPrivatePlanId !== null;
    }
    return false;
  }

  isStepCurrent(stepKey: PublicPlanResultsNextStep['stepKey']): boolean {
    if (stepKey === 'save') {
      return !this.isStepComplete('save') && (this.isLoggedIn || !this.savedPrivatePlanId);
    }
    return false;
  }
}

export function buildPublicPlanResultsNextSteps(
  savedPrivatePlanId: number | null
): PublicPlanResultsNextStep[] {
  const planBase =
    savedPrivatePlanId !== null ? (['/plans', savedPrivatePlanId] as (string | number)[]) : null;

  return [
    {
      stepKey: 'save',
      stepNumber: 1,
      titleKey: 'public_plans.results.next_steps.save.title',
      descriptionKey: 'public_plans.results.next_steps.save.description'
    },
    {
      stepKey: 'task_schedule',
      stepNumber: 2,
      titleKey: 'public_plans.results.next_steps.task_schedule.title',
      descriptionKey: 'public_plans.results.next_steps.task_schedule.description',
      commands: planBase ? [...planBase, 'task_schedule'] : undefined
    },
    {
      stepKey: 'work_record',
      stepNumber: 3,
      titleKey: 'public_plans.results.next_steps.work_record.title',
      descriptionKey: 'public_plans.results.next_steps.work_record.description',
      commands: planBase ? [...planBase, 'work_records'] : undefined
    }
  ];
}
