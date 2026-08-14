import { CommonModule } from '@angular/common';
import { Component, Input, inject } from '@angular/core';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  buildLearnReorganizePipelineResumeNavigation,
  readLearnReorganizePipelineAutoChain,
  readLearnReorganizePipelineFailure,
  retryLearnReorganizePipeline
} from '../../domain/plans/learn-reorganize-pipeline-auto-chain';

@Component({
  selector: 'app-plan-learn-pipeline-status',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    @if (pipelineFailure; as failure) {
      <section class="learn-pipeline-status learn-pipeline-status--error" role="alert">
        <h3 class="learn-pipeline-status__title">
          {{ 'plans.learn.pipeline.error_title' | translate }}
        </h3>
        <p class="learn-pipeline-status__message">{{ failure.errorMessage }}</p>
        <button type="button" class="btn btn-primary" (click)="retryPipeline()">
          {{ 'plans.learn.pipeline.retry' | translate }}
        </button>
      </section>
    } @else if (pipelineActive) {
      <section class="learn-pipeline-status" role="status">
        <p class="learn-pipeline-status__message">
          {{ 'plans.learn.pipeline.resume_message' | translate }}
        </p>
        <button type="button" class="btn btn-primary" (click)="resumePipeline()">
          {{ 'plans.learn.pipeline.resume' | translate }}
        </button>
      </section>
    }
  `,
  styleUrls: ['./plan-learn-pipeline-status.component.css']
})
export class PlanLearnPipelineStatusComponent {
  private readonly router = inject(Router);

  @Input({ required: true }) planId!: number;

  get pipelineActive(): boolean {
    return readLearnReorganizePipelineAutoChain(this.planId);
  }

  get pipelineFailure(): { failedPhase: string; errorMessage: string } | null {
    return readLearnReorganizePipelineFailure(this.planId);
  }

  resumePipeline(): void {
    const navigation = buildLearnReorganizePipelineResumeNavigation(this.planId);
    if (!navigation) {
      return;
    }
    void this.router.navigate(navigation.commands, {
      queryParams: navigation.queryParams
    });
  }

  retryPipeline(): void {
    const navigation = retryLearnReorganizePipeline(this.planId);
    if (!navigation) {
      return;
    }
    void this.router.navigate(navigation.commands, {
      queryParams: navigation.queryParams
    });
  }
}
