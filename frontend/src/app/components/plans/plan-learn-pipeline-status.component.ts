import { Component, Input, inject, Output, EventEmitter } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  buildLearnOrchestrationResumeNavigation,
  hasLearnReorganizePipelineFailure,
  readLearnOrchestrationCurrentPhase,
  readLearnOrchestrationLastError
} from '../../domain/plans/learn-master-update-orchestration';
import { clearLearnReorganizePipelineError } from '../../domain/plans/learn-reorganize-pipeline-auto-chain';
import { buildLearnReorganizeSkipPlacementOptimizingNavigation } from '../../domain/plans/learn-reorganize-skip-placement-pipeline';
import { resolveLearnReorganizePipelineStageLabelKey } from '../../domain/plans/resolve-learn-reorganize-pipeline-stage';
import { StartLearnOneClickReoptimizeUseCase } from '../../usecase/plans/start-learn-one-click-reoptimize.usecase';

@Component({
  selector: 'app-plan-learn-pipeline-status',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    @if (showFailure) {
      <section class="learn-pipeline-status" role="alert" aria-live="polite">
        <h3 class="learn-pipeline-status__title">
          {{ 'plans.learn.pipeline_status.failed_title' | translate }}
        </h3>
        <p class="learn-pipeline-status__message">{{ errorMessage }}</p>
        <div class="learn-pipeline-status__actions">
          <button type="button" class="btn btn-primary" (click)="retryPipeline()">
            {{ 'plans.learn.pipeline_status.retry' | translate }}
          </button>
          @if (resumeNavigation) {
            <a
              class="btn btn-secondary"
              [routerLink]="resumeNavigation.commands"
              [queryParams]="resumeNavigation.queryParams"
            >
              {{ 'plans.learn.pipeline_status.resume' | translate }}
            </a>
          }
        </div>
      </section>
    } @else if (showActive) {
      <section class="learn-pipeline-status learn-pipeline-status--active" aria-live="polite">
        @if (phaseLabelKey) {
          <p class="learn-pipeline-status__phase">{{ phaseLabelKey | translate }}</p>
        }
        <p class="learn-pipeline-status__active-message">
          {{ 'plans.learn.pipeline_status.active_message' | translate }}
        </p>
        @if (resumeNavigation) {
          <a
            class="btn btn-primary learn-pipeline-status__continue"
            [routerLink]="resumeNavigation.commands"
            [queryParams]="resumeNavigation.queryParams"
          >
            {{ 'plans.learn.pipeline_status.resume' | translate }}
          </a>
        }
      </section>
    }
  `,
  styleUrls: ['./plan-learn-pipeline-status.component.css']
})
export class PlanLearnPipelineStatusComponent {
  private readonly router = inject(Router);
  private readonly oneClickReoptimizeUseCase = inject(StartLearnOneClickReoptimizeUseCase);

  @Input({ required: true }) planId!: number;
  @Input() refreshVersion = 0;
  @Output() progressChanged = new EventEmitter<void>();

  get showFailure(): boolean {
    void this.refreshVersion;
    return hasLearnReorganizePipelineFailure(this.planId);
  }

  get showActive(): boolean {
    void this.refreshVersion;
    return !this.showFailure && this.resumeNavigation != null;
  }

  get errorMessage(): string {
    void this.refreshVersion;
    return (
      readLearnOrchestrationLastError(this.planId) ??
      'plans.learn.pipeline_status.unknown_error'
    );
  }

  get phaseLabelKey(): string | null {
    void this.refreshVersion;
    return resolveLearnReorganizePipelineStageLabelKey(
      readLearnOrchestrationCurrentPhase(this.planId)
    );
  }

  get resumeNavigation(): ReturnType<typeof buildLearnOrchestrationResumeNavigation> {
    void this.refreshVersion;
    return buildLearnOrchestrationResumeNavigation(this.planId);
  }

  retryPipeline(): void {
    clearLearnReorganizePipelineError(this.planId);
    this.oneClickReoptimizeUseCase.execute({
      planId: this.planId,
      onSuccess: () => {
        const navigation = buildLearnReorganizeSkipPlacementOptimizingNavigation(this.planId);
        void this.router.navigate(navigation.commands);
        this.progressChanged.emit();
      },
      onError: () => {
        this.progressChanged.emit();
      }
    });
  }
}
