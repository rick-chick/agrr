import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import {
  buildLearnLoopPhaseInputFromState,
  buildLearnLoopPhaseResult,
  LEARN_LOOP_PHASE_ORDER,
  type LearnLoopNextAction,
  type LearnLoopPhaseId
} from '../../domain/plans/learn-loop-phase';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';

@Component({
  selector: 'app-plan-learn-loop-progress',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    <section
      class="learn-loop-progress"
      aria-labelledby="plan-learn-loop-progress-heading"
    >
      <h2 id="plan-learn-loop-progress-heading" class="learn-loop-progress__title">
        {{ 'plans.learn.loop.title' | translate }}
      </h2>
      <ol class="learn-loop-progress__bar" role="list">
        @for (phase of phases; track phase; let index = $index) {
          <li
            class="learn-loop-progress__phase"
            [class.learn-loop-progress__phase--current]="phase === currentPhase"
            [class.learn-loop-progress__phase--completed]="phaseIndex(phase) < phaseIndex(currentPhase)"
            [attr.aria-current]="phase === currentPhase ? 'step' : null"
          >
            <span class="learn-loop-progress__phase-index">{{ index + 1 }}</span>
            <span class="learn-loop-progress__phase-label">{{
              phaseLabelKey(phase) | translate
            }}</span>
          </li>
        }
      </ol>
      @if (loopComplete) {
        <div
          class="learn-loop-progress__complete"
          role="status"
          aria-labelledby="plan-learn-loop-complete-heading"
        >
          <h3 id="plan-learn-loop-complete-heading" class="learn-loop-progress__complete-title">
            {{ 'plans.learn.loop.complete.title' | translate }}
          </h3>
          <p class="learn-loop-progress__complete-lead">
            {{ 'plans.learn.loop.complete.lead' | translate }}
          </p>
        </div>
      }
      @if (nextAction) {
        <div class="learn-loop-progress__next">
          @if (currentPhase === 'complete') {
            <p class="learn-loop-progress__complete-message" role="status">
              {{ 'plans.learn.loop.complete_message' | translate }}
            </p>
          }
<<<<<<< HEAD
          @if (showHandoffSourcePlan) {
            <p class="learn-loop-progress__handoff-source" role="status">
              {{ 'plans.learn.loop.handoff_source_plan' | translate: { planName: planName } }}
            </p>
          }
=======
>>>>>>> b46ec83768ac8e444bb66172af8692ce443efd8f
          <p class="learn-loop-progress__next-label">
            {{ 'plans.learn.loop.next_action_title' | translate }}:
            {{ nextAction.labelKey | translate }}
          </p>
          @if (nextAction.kind === 'router_link') {
            <a
              class="btn btn-primary learn-loop-progress__next-cta"
              [routerLink]="nextAction.routerLink"
              [queryParams]="nextAction.queryParams"
            >
              {{ nextAction.labelKey | translate }}
            </a>
          } @else {
            <a
              class="btn btn-primary learn-loop-progress__next-cta"
              [href]="scrollHref(nextAction)"
            >
              {{ nextAction.labelKey | translate }}
            </a>
          }
          @if (secondaryAction; as secondary) {
            @if (secondary.kind === 'router_link') {
              <a
                class="btn btn-secondary learn-loop-progress__secondary-cta"
                [routerLink]="secondary.routerLink"
                [queryParams]="secondary.queryParams"
              >
                {{ secondary.labelKey | translate }}
              </a>
            }
          }
        </div>
      }
    </section>
  `,
  styleUrls: ['./plan-learn-loop-progress.component.css']
})
export class PlanLearnLoopProgressComponent {
  @Input({ required: true }) planId!: number;
  @Input() planName: string | null = null;
  @Input() actionRequiredItems: PlanVarianceActionItem[] = [];
  @Input() stageGddProposals: StageGddCalibrationProposal[] = [];
  @Input() blueprintTimingProposals: BlueprintTimingAdjustmentProposal[] = [];
  @Input() hasPostMasterConfirmation = false;
  @Input() hasMasterUpdateNextSteps = false;
  @Input() hasLearningSnapshot = false;
  @Input() carryoverSourcePlanCount = 0;
  @Input() progressRefreshVersion = 0;

  readonly phases = LEARN_LOOP_PHASE_ORDER;

  get loopComplete(): boolean {
    void this.progressRefreshVersion;
    return this.phaseInput.loopComplete;
  }

  get currentPhase(): LearnLoopPhaseId {
    return this.phaseResult.currentPhase;
  }

  get nextAction(): LearnLoopNextAction | null {
    return this.phaseResult.nextAction;
  }

  get secondaryAction(): LearnLoopNextAction | null | undefined {
    return this.phaseResult.secondaryAction;
  }

  get showHandoffSourcePlan(): boolean {
    return (
      this.currentPhase === 'handoff' &&
      this.planName != null &&
      this.nextAction?.labelKey === 'plans.learn.loop.next_action.handoff_new_plan'
    );
  }

  private get phaseInput(): ReturnType<typeof buildLearnLoopPhaseInputFromState> {
    void this.progressRefreshVersion;
    return buildLearnLoopPhaseInputFromState({
      planId: this.planId,
      actionRequiredItems: this.actionRequiredItems,
      stageGddProposals: this.stageGddProposals,
      blueprintTimingProposals: this.blueprintTimingProposals,
      hasPostMasterConfirmation: this.hasPostMasterConfirmation,
      hasMasterUpdateNextSteps: this.hasMasterUpdateNextSteps,
      hasLearningSnapshot: this.hasLearningSnapshot,
      carryoverSourcePlanCount: this.carryoverSourcePlanCount
    });
  }

  private get phaseResult(): ReturnType<typeof buildLearnLoopPhaseResult> {
    return buildLearnLoopPhaseResult(this.phaseInput);
  }

  phaseLabelKey(phase: LearnLoopPhaseId): string {
    return `plans.learn.loop.phase.${phase}`;
  }

  phaseIndex(phase: LearnLoopPhaseId): number {
    return LEARN_LOOP_PHASE_ORDER.indexOf(phase);
  }

  scrollHref(action: LearnLoopNextAction): string {
    return action.scrollTargetId ? `#${action.scrollTargetId}` : '#';
  }
}
