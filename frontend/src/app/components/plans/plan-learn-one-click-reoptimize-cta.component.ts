import { Component, Input, inject, ChangeDetectorRef } from '@angular/core';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  buildLearnReorganizeSkipPlacementOptimizingNavigation,
  shouldShowLearnOneClickReoptimizeCta
} from '../../domain/plans/learn-reorganize-skip-placement-pipeline';
import { StartLearnVarianceLearningReoptimizeUseCase } from '../../usecase/plans/start-learn-variance-learning-reoptimize.usecase';

@Component({
  selector: 'app-plan-learn-one-click-reoptimize-cta',
  standalone: true,
  imports: [TranslateModule],
  template: `
    @if (visible) {
      <section
        class="learn-one-click-reoptimize"
        aria-labelledby="learn-one-click-reoptimize-heading"
      >
        <h3 id="learn-one-click-reoptimize-heading" class="learn-one-click-reoptimize__title">
          {{ 'plans.learn.one_click_reoptimize.title' | translate }}
        </h3>
        <p class="learn-one-click-reoptimize__lead">
          {{ 'plans.learn.one_click_reoptimize.lead' | translate }}
        </p>
        @if (errorMessage) {
          <p class="learn-one-click-reoptimize__error" role="alert">{{ errorMessage | translate }}</p>
        }
        <button
          type="button"
          class="btn-primary learn-one-click-reoptimize__cta"
          [disabled]="starting"
          (click)="startReoptimize()"
        >
          {{
            (starting
              ? 'plans.learn.one_click_reoptimize.starting'
              : 'plans.learn.one_click_reoptimize.cta') | translate
          }}
        </button>
      </section>
    }
  `,
  styleUrls: ['./plan-learn-one-click-reoptimize-cta.component.css']
})
export class PlanLearnOneClickReoptimizeCtaComponent {
  private readonly router = inject(Router);
  private readonly useCase = inject(StartLearnVarianceLearningReoptimizeUseCase);
  private readonly cdr = inject(ChangeDetectorRef);

  @Input({ required: true }) planId!: number;
  @Input() refreshVersion = 0;

  starting = false;
  errorMessage: string | null = null;

  get visible(): boolean {
    void this.refreshVersion;
    return shouldShowLearnOneClickReoptimizeCta(this.planId);
  }

  startReoptimize(): void {
    if (this.starting) {
      return;
    }
    this.starting = true;
    this.errorMessage = null;
    this.useCase.execute({
      planId: this.planId,
      onSuccess: () => {
        this.starting = false;
        const navigation = buildLearnReorganizeSkipPlacementOptimizingNavigation(this.planId);
        void this.router.navigate(navigation.commands);
        this.cdr.markForCheck();
      },
      onError: (message) => {
        this.starting = false;
        this.errorMessage = message;
        this.cdr.markForCheck();
      }
    });
  }
}
