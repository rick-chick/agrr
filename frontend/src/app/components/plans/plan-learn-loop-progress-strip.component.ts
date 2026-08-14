import { Component, Input, OnChanges, OnDestroy, OnInit, SimpleChanges, inject } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { PLAN_LEARN_PROVIDERS } from '../../usecase/plans/plan-learn.providers';
import type { LearnLoopPhaseId } from '../../domain/plans/learn-loop-phase';
import { learnNavBadgePhaseLabelKey } from '../../domain/plans/learn-loop-cross-display';
import {
  PlanLearnLoopSummaryCoordinator,
  type PlanLearnLoopSummarySnapshot
} from '../../usecase/plans/plan-learn-loop-summary.coordinator';

@Component({
  selector: 'app-plan-learn-loop-progress-strip',
  standalone: true,
  imports: [TranslateModule],
  providers: [...PLAN_LEARN_PROVIDERS, PlanLearnLoopSummaryCoordinator],
  template: `
    @if (snapshot && !snapshot.loading) {
      <div
        class="learn-loop-progress-strip"
        role="status"
        aria-labelledby="learn-loop-progress-strip-heading"
      >
        <p id="learn-loop-progress-strip-heading" class="learn-loop-progress-strip__title">
          {{ 'plans.learn.loop.title' | translate }}
        </p>
        <ol class="learn-loop-progress-strip__bar" role="list">
          @for (phase of snapshot.crossDisplay.phases; track phase; let index = $index) {
            <li
              class="learn-loop-progress-strip__phase"
              [class.learn-loop-progress-strip__phase--current]="
                phase === snapshot.crossDisplay.currentPhase
              "
              [class.learn-loop-progress-strip__phase--completed]="
                index < phaseIndex(snapshot.crossDisplay.currentPhase)
              "
              [attr.aria-current]="phase === snapshot.crossDisplay.currentPhase ? 'step' : null"
            >
              <span class="learn-loop-progress-strip__phase-label">{{
                phaseLabelKey(phase) | translate
              }}</span>
            </li>
          }
        </ol>
      </div>
    }
  `,
  styleUrls: ['./plan-learn-loop-progress-strip.component.css']
})
export class PlanLearnLoopProgressStripComponent implements OnInit, OnChanges, OnDestroy {
  @Input({ required: true }) planId!: number;

  private readonly coordinator = inject(PlanLearnLoopSummaryCoordinator);
  private unsubscribe: (() => void) | null = null;

  snapshot: PlanLearnLoopSummarySnapshot | null = null;

  ngOnInit(): void {
    this.unsubscribe = this.coordinator.subscribe((snapshot) => {
      this.snapshot = snapshot;
    });
    this.coordinator.load(this.planId);
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['planId'] && !changes['planId'].firstChange) {
      this.coordinator.load(this.planId);
    }
  }

  ngOnDestroy(): void {
    this.unsubscribe?.();
  }

  phaseLabelKey(phase: LearnLoopPhaseId): string {
    return learnNavBadgePhaseLabelKey(phase);
  }

  phaseIndex(phase: LearnLoopPhaseId): number {
    return this.snapshot?.crossDisplay.phases.indexOf(phase) ?? -1;
  }
}
