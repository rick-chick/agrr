import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  buildPlanDetailAdjustNavigation,
  buildPlanTaskScheduleOrchestrationNavigation,
  readLearnOrchestrationStepComplete
} from '../../domain/plans/learn-master-update-orchestration';

export interface LearnMasterUpdateNextStep {
  stepKey: 'placement' | 'regenerate' | 'sync_verify';
  stepNumber: 1 | 2 | 3;
  titleKey: string;
  descriptionKey: string;
  commands: (string | number)[];
  queryParams: { learningOrchestration: string };
}

@Component({
  selector: 'app-plan-learn-master-update-next-steps',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    @if (visible) {
      <section
        class="learn-next-steps"
        aria-labelledby="learn-next-steps-heading"
      >
        <h3 id="learn-next-steps-heading" class="learn-next-steps__title">
          {{ 'plans.learn.next_steps.title' | translate }}
        </h3>
        <p class="learn-next-steps__lead">
          {{ 'plans.learn.next_steps.lead' | translate }}
        </p>
        <ol class="learn-next-steps__list" role="list">
          @for (step of steps; track step.stepKey) {
            <li
              class="learn-next-steps__item"
              [class.learn-next-steps__item--completed]="isStepComplete(step.stepKey)"
            >
              <div class="learn-next-steps__item-main">
                <span class="learn-next-steps__step-label">{{
                  stepLabel(step.stepNumber) | translate
                }}</span>
                <span class="learn-next-steps__step-title">{{ step.titleKey | translate }}</span>
                <p class="learn-next-steps__step-description">
                  {{ step.descriptionKey | translate }}
                </p>
              </div>
              @if (isStepComplete(step.stepKey)) {
                <span class="learn-next-steps__completed-badge">{{
                  'plans.learn.next_steps.completed' | translate
                }}</span>
              } @else {
                <a
                  class="btn-secondary learn-next-steps__cta"
                  [routerLink]="step.commands"
                  [queryParams]="step.queryParams"
                >
                  {{ ctaKey(step.stepKey) | translate }}
                </a>
              }
            </li>
          }
        </ol>
      </section>
    }
  `,
  styleUrls: ['./plan-learn-master-update-next-steps.component.css']
})
export class PlanLearnMasterUpdateNextStepsComponent {
  @Input({ required: true }) planId!: number;
  @Input() visible = false;

  get steps(): LearnMasterUpdateNextStep[] {
    return buildLearnMasterUpdateNextSteps(this.planId);
  }

  stepLabel(stepNumber: 1 | 2 | 3): string {
    return `plans.learn.next_steps.step_label.${stepNumber}`;
  }

  ctaKey(stepKey: LearnMasterUpdateNextStep['stepKey']): string {
    return `plans.learn.next_steps.cta.${stepKey}`;
  }

  isStepComplete(stepKey: LearnMasterUpdateNextStep['stepKey']): boolean {
    return readLearnOrchestrationStepComplete(this.planId, stepKey);
  }
}

export function buildLearnMasterUpdateNextSteps(planId: number): LearnMasterUpdateNextStep[] {
  const adjust = buildPlanDetailAdjustNavigation(planId);
  const regenerate = buildPlanTaskScheduleOrchestrationNavigation(planId, 'regenerate');
  const syncVerify = buildPlanTaskScheduleOrchestrationNavigation(planId, 'sync_verify');

  return [
    {
      stepKey: 'placement',
      stepNumber: 1,
      titleKey: 'plans.learn.next_steps.placement.title',
      descriptionKey: 'plans.learn.next_steps.placement.description',
      commands: adjust.commands,
      queryParams: adjust.queryParams
    },
    {
      stepKey: 'regenerate',
      stepNumber: 2,
      titleKey: 'plans.learn.next_steps.regenerate.title',
      descriptionKey: 'plans.learn.next_steps.regenerate.description',
      commands: regenerate.commands,
      queryParams: regenerate.queryParams
    },
    {
      stepKey: 'sync_verify',
      stepNumber: 3,
      titleKey: 'plans.learn.next_steps.sync_verify.title',
      descriptionKey: 'plans.learn.next_steps.sync_verify.description',
      commands: syncVerify.commands,
      queryParams: syncVerify.queryParams
    }
  ];
}
