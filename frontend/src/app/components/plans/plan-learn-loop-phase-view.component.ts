import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  LEARN_LOOP_PHASES,
  resolveLearnLoopPhase,
  type LearnLoopPhase,
  type LearnLoopPhaseInput,
  type LearnLoopPhaseState
} from '../../domain/plans/learn-loop-phase';

@Component({
  selector: 'app-plan-learn-loop-phase-view',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    @if (phaseState.nextAction) {
      <section
        class="learn-loop-phase"
        aria-labelledby="learn-loop-phase-heading"
      >
        <h2 id="learn-loop-phase-heading" class="learn-loop-phase__heading">
          {{ 'plans.learn.loop_phase.title' | translate }}
        </h2>

        <ol class="learn-loop-phase__progress" role="list" aria-label="{{ 'plans.learn.loop_phase.progress_aria' | translate }}">
          @for (phase of phases; track phase) {
            <li
              class="learn-loop-phase__step"
              [class.learn-loop-phase__step--completed]="isCompleted(phase)"
              [class.learn-loop-phase__step--current]="isCurrent(phase)"
              [attr.aria-current]="isCurrent(phase) ? 'step' : null"
            >
              <span class="learn-loop-phase__step-marker" aria-hidden="true">
                @if (isCompleted(phase)) {
                  ✓
                } @else {
                  {{ phaseIndex(phase) + 1 }}
                }
              </span>
              <span class="learn-loop-phase__step-label">{{
                phaseLabel(phase) | translate
              }}</span>
            </li>
          }
        </ol>

        <div class="learn-loop-phase__next-action" role="status">
          <p class="learn-loop-phase__current">
            {{ 'plans.learn.loop_phase.current_label' | translate }}:
            <strong>{{ phaseLabel(phaseState.currentPhase) | translate }}</strong>
          </p>
          <a
            class="btn btn-primary learn-loop-phase__cta"
            [routerLink]="phaseState.nextAction.commands"
            [queryParams]="phaseState.nextAction.queryParams"
          >
            {{ phaseState.nextAction.labelKey | translate }}
          </a>
        </div>
      </section>
    }
  `,
  styleUrls: ['./plan-learn-loop-phase-view.component.css']
})
export class PlanLearnLoopPhaseViewComponent {
  @Input({ required: true }) planId!: number;
  @Input() phaseInput: LearnLoopPhaseInput | null = null;

  readonly phases = LEARN_LOOP_PHASES;

  get phaseState(): LearnLoopPhaseState {
    if (!this.phaseInput) {
      return {
        currentPhase: 'observe',
        completedPhases: [],
        nextAction: null
      };
    }
    return resolveLearnLoopPhase(this.phaseInput);
  }

  phaseLabel(phase: LearnLoopPhase): string {
    return `plans.learn.loop_phase.steps.${phase}`;
  }

  phaseIndex(phase: LearnLoopPhase): number {
    return LEARN_LOOP_PHASES.indexOf(phase);
  }

  isCompleted(phase: LearnLoopPhase): boolean {
    return this.phaseState.completedPhases.includes(phase);
  }

  isCurrent(phase: LearnLoopPhase): boolean {
    return this.phaseState.currentPhase === phase;
  }
}
