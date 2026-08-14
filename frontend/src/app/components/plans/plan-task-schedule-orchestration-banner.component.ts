import { Component, DestroyRef, Input, OnInit, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { collectLearnProposalRawSources } from '../../domain/plans/collect-learn-proposal-raw-sources';
import {
  buildLearnLoopPhaseInputFromState,
  buildLearnLoopPhaseResult,
  LEARN_LOOP_PHASE_ORDER,
  type LearnLoopPhaseId
} from '../../domain/plans/learn-loop-phase';
import { mapLearnProposalRawSourcesToPhaseProposals } from '../../domain/plans/map-learn-proposal-raw-sources-to-phase-proposals';
import { hydrateLearnOrchestrationProgress } from '../../domain/plans/learn-master-update-orchestration';
import type { LearningOrchestrationMode } from '../../domain/plans/learn-master-update-orchestration';
import { hydrateLearnProposalApplicationProgress } from '../../domain/plans/learn-proposal-application-progress';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { PLAN_GATEWAY, PlanGateway } from '../../usecase/plans/plan-gateway';

@Component({
  selector: 'app-plan-task-schedule-orchestration-banner',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  providers: [{ provide: PLAN_GATEWAY, useClass: PlanApiGateway }],
  template: `
    @if (mode) {
      <div class="learn-orchestration-banner" role="status" aria-live="polite">
        @if (currentPhase) {
          <div
            class="learn-orchestration-banner__loop-progress"
            aria-labelledby="learn-orchestration-loop-progress-heading"
          >
            <p id="learn-orchestration-loop-progress-heading" class="learn-orchestration-banner__loop-title">
              {{ 'plans.task_schedules.orchestration.loop_progress_title' | translate }}
            </p>
            <ol class="learn-orchestration-banner__loop-phases" role="list">
              @for (phase of phases; track phase; let index = $index) {
                <li
                  class="learn-orchestration-banner__loop-phase"
                  [class.learn-orchestration-banner__loop-phase--current]="phase === currentPhase"
                  [class.learn-orchestration-banner__loop-phase--completed]="phaseIndex(phase) < phaseIndex(currentPhase)"
                >
                  <span class="learn-orchestration-banner__loop-phase-index">{{ index + 1 }}</span>
                  <span class="learn-orchestration-banner__loop-phase-label">{{
                    phaseLabelKey(phase) | translate
                  }}</span>
                </li>
              }
            </ol>
          </div>
        }
        <p class="learn-orchestration-banner__message">
          {{ messageKey | translate }}
        </p>
        <p class="learn-orchestration-banner__hint">
          {{ hintKey | translate }}
        </p>
        @if (showWorkRetryLink) {
          <a class="btn-secondary learn-orchestration-banner__work-link" [routerLink]="workLink">
            {{ 'plans.task_schedules.orchestration.work_retry' | translate }}
          </a>
        }
        @if (showReturnToLearnLink) {
          <a class="btn-primary learn-orchestration-banner__learn-link" [routerLink]="learnLink">
            {{ 'plans.task_schedules.orchestration.return_to_learn' | translate }}
          </a>
        }
      </div>
    }
  `,
  styleUrls: ['./plan-task-schedule-orchestration-banner.component.css']
})
export class PlanTaskScheduleOrchestrationBannerComponent implements OnInit {
  @Input({ required: true }) planId!: number;
  @Input() mode: LearningOrchestrationMode | null = null;
  @Input() syncState: string | null = null;

  readonly phases = LEARN_LOOP_PHASE_ORDER;
  currentPhase: LearnLoopPhaseId | null = null;

  private readonly gateway = inject<PlanGateway>(PLAN_GATEWAY);
  private readonly destroyRef = inject(DestroyRef);

  ngOnInit(): void {
    forkJoin({
      varianceSummary: this.gateway.getPlanVsActualSummary(this.planId),
      learningSnapshot: this.gateway.getVarianceLearning(this.planId).pipe(catchError(() => of(null)))
    })
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: ({ varianceSummary, learningSnapshot }) => {
          if (learningSnapshot?.proposal_application_progress) {
            hydrateLearnProposalApplicationProgress(
              this.planId,
              learningSnapshot.proposal_application_progress
            );
          }
          if (learningSnapshot?.reorganize_orchestration_progress) {
            hydrateLearnOrchestrationProgress(
              this.planId,
              learningSnapshot.reorganize_orchestration_progress
            );
          }

          const rawSources = collectLearnProposalRawSources(varianceSummary, learningSnapshot);
          const { stageGddProposals, blueprintTimingProposals } =
            mapLearnProposalRawSourcesToPhaseProposals(rawSources);
          const phaseInput = buildLearnLoopPhaseInputFromState({
            planId: this.planId,
            actionRequiredItems: varianceSummary.action_required_items ?? [],
            stageGddProposals,
            blueprintTimingProposals,
            hasPostMasterConfirmation: false,
            hasMasterUpdateNextSteps: false,
            hasLearningSnapshot: learningSnapshot != null,
            carryoverSourcePlanCount: 0
          });
          this.currentPhase = buildLearnLoopPhaseResult(phaseInput).currentPhase;
        },
        error: () => {
          this.currentPhase = null;
        }
      });
  }

  get messageKey(): string {
    if (this.mode === 'regenerate') {
      return 'plans.task_schedules.orchestration.regenerate.message';
    }
    return 'plans.task_schedules.orchestration.sync_verify.message';
  }

  get hintKey(): string {
    if (this.mode === 'regenerate') {
      return 'plans.task_schedules.orchestration.regenerate.hint';
    }
    return 'plans.task_schedules.orchestration.sync_verify.hint';
  }

  get showWorkRetryLink(): boolean {
    return this.mode === 'sync_verify' && this.syncState === 'failed';
  }

  get showReturnToLearnLink(): boolean {
    return this.mode === 'regenerate' || this.mode === 'sync_verify';
  }

  get workLink(): (string | number)[] {
    return ['/plans', this.planId, 'work'];
  }

  get learnLink(): (string | number)[] {
    return ['/plans', this.planId, 'learn'];
  }

  phaseLabelKey(phase: LearnLoopPhaseId): string {
    return `plans.learn.loop.phase.${phase}`;
  }

  phaseIndex(phase: LearnLoopPhaseId): number {
    return LEARN_LOOP_PHASE_ORDER.indexOf(phase);
  }
}
