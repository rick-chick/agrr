import { Component, OnDestroy, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { Channel } from 'actioncable';
import { PlanOptimizingView, PlanOptimizingViewState } from './plan-optimizing.view';
import { SubscribePlanOptimizationUseCase } from '../../usecase/plans/subscribe-plan-optimization.usecase';
import { PlanOptimizingPresenter, PLAN_OPTIMIZING_PROVIDERS } from '../../usecase/plans/plan-optimizing.providers';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';
import {
  clearLearnOrchestrationReturnToLearn,
  markLearnOrchestrationStepComplete,
  readLearnOrchestrationReturnToLearn
} from '../../domain/plans/learn-master-update-orchestration';
import {
  buildLearnReorganizePipelineRegenerateNavigation,
  readLearnReorganizePipelineAutoChain,
  reportLearnReorganizePipelineFailure,
  setLearnReorganizePipelinePhase
} from '../../domain/plans/learn-reorganize-pipeline-auto-chain';

const initialControl: PlanOptimizingViewState = {
  status: 'pending',
  progress: 0,
  phaseMessage: ''
};

@Component({
  selector: 'app-plan-optimizing',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, PlanPlanContextHeaderComponent],
  providers: [...PLAN_OPTIMIZING_PROVIDERS],
  template: `
    <div class="page-main page-main--fit">
      <app-plan-plan-context-header
        [planId]="planId"
        [planName]="null"
        pageTitleKey="plans.optimizing_live.heading"
      />
      <section class="page">
        @if (isFailed) {
          <div class="page-alert-error plan-optimizing__error" role="alert">
            <p>{{ control.phaseMessage }}</p>
            @if (control.failureHint) {
              <p class="plan-optimizing__failure-hint">{{ control.failureHint }}</p>
            }
            <div class="plan-optimizing__error-actions">
              <button type="button" class="btn-secondary plan-optimizing__retry" (click)="reload()">
                {{ 'plans.optimizing_live.error.retry' | translate }}
              </button>
              <a [routerLink]="['/plans', planId]" class="btn-secondary plan-optimizing__back">
                {{ 'plans.optimizing_live.error.back_to_plan' | translate }}
              </a>
            </div>
          </div>
        } @else {
          <h2>
            <span>{{
              (isCompleted
                ? 'plans.optimizing_live.heading_completed'
                : 'plans.optimizing_live.heading'
              ) | translate
            }}</span>
            @if (isCompleted) {
              <span class="status-badge status-badge--completed">{{
                'plans.optimizing_live.status_badge_completed' | translate
              }}</span>
            }
          </h2>
          <p>{{ 'plans.optimizing_live.progress_label' | translate: { progress: control.progress } }}</p>
          @if (!isCompleted) {
            <p class="plan-optimizing__phase-message">{{
              control.phaseMessage || ('plans.optimizing_live.default_message' | translate)
            }}</p>
            <p class="plan-optimizing__duration-hint">{{
              'plans.optimizing_live.duration_hint' | translate
            }}</p>
          } @else if (control.phaseMessage) {
            <p class="plan-optimizing__phase-message">{{ control.phaseMessage }}</p>
          }
        }
      </section>
    </div>
  `,
  styleUrls: ['./plan-optimizing.component.css']
})
export class PlanOptimizingComponent implements PlanOptimizingView, OnDestroy, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(SubscribePlanOptimizationUseCase);
  private readonly presenter = inject(PlanOptimizingPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private channel: Channel | null = null;

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  get isCompleted(): boolean {
    return this.control.status === 'completed' || this.control.progress >= 100;
  }

  get isFailed(): boolean {
    return this.control.status === 'failed';
  }

  private _control: PlanOptimizingViewState = initialControl;
  get control(): PlanOptimizingViewState {
    return this._control;
  }
  set control(value: PlanOptimizingViewState) {
    const previous = this._control;
    this._control = value;
    const planId = this.planId;
    if (
      planId &&
      value.status === 'failed' &&
      previous.status !== 'failed' &&
      readLearnReorganizePipelineAutoChain(planId)
    ) {
      reportLearnReorganizePipelineFailure(planId, 'optimizing', value.phaseMessage);
    }
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const planId = this.planId;
    if (!planId) {
      this.control = { status: 'invalid_plan_id', progress: 0, phaseMessage: '' };
      return;
    }
    if (readLearnReorganizePipelineAutoChain(planId)) {
      setLearnReorganizePipelinePhase(planId, 'optimizing');
    }
    this.subscribeOptimization(planId);
  }

  reload(): void {
    const planId = this.planId;
    if (!planId) {
      return;
    }
    this.channel?.unsubscribe();
    this.channel = null;
    this.control = { status: 'pending', progress: 0, phaseMessage: '' };
    this.subscribeOptimization(planId);
  }

  onOptimizationCompleted(): void {
    const planId = this.planId;
    if (planId && readLearnReorganizePipelineAutoChain(planId)) {
      markLearnOrchestrationStepComplete(planId, 'placement');
      setLearnReorganizePipelinePhase(planId, 'regenerate');
      const navigation = buildLearnReorganizePipelineRegenerateNavigation(planId);
      void this.router.navigate(navigation.commands, { queryParams: navigation.queryParams });
      return;
    }
    if (planId && readLearnOrchestrationReturnToLearn(planId)) {
      clearLearnOrchestrationReturnToLearn(planId);
      markLearnOrchestrationStepComplete(planId, 'placement');
      void this.router.navigate(['/plans', planId, 'learn']);
      return;
    }
    void this.router.navigate(['/plans', planId]);
  }

  ngOnDestroy(): void {
    this.channel?.unsubscribe();
  }

  private subscribeOptimization(planId: number): void {
    this.useCase.execute({
      planId,
      onSubscribed: (ch) => {
        this.channel = ch;
      }
    });
  }
}
