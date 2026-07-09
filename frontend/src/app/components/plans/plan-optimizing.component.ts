import { Component, OnDestroy, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { Channel } from 'actioncable';
import { PlanOptimizingView, PlanOptimizingViewState } from './plan-optimizing.view';
import { SubscribePlanOptimizationUseCase } from '../../usecase/plans/subscribe-plan-optimization.usecase';
import { PlanOptimizingPresenter, PLAN_OPTIMIZING_PROVIDERS } from '../../usecase/plans/plan-optimizing.providers';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';

const initialControl: PlanOptimizingViewState = {
  status: 'pending',
  progress: 0,
  phaseMessage: ''
};

@Component({
  selector: 'app-plan-optimizing',
  standalone: true,
  imports: [CommonModule, TranslateModule, PlanPlanContextHeaderComponent],
  providers: [...PLAN_OPTIMIZING_PROVIDERS],
  template: `
    <main class="page-main page-main--fit">
      <app-plan-plan-context-header
        [planId]="planId"
        [planName]="null"
        pageTitleKey="plans.optimizing_live.heading"
      />
      <section class="page">
        <h2>
          <span>{{
            (isCompleted
              ? 'plans.optimizing_live.heading_completed'
              : 'plans.optimizing_live.heading'
            ) | translate
          }}</span>
          <span class="status-badge" [class.status-badge--completed]="isCompleted">{{
            (isCompleted
              ? 'plans.optimizing_live.status_badge_completed'
              : 'plans.optimizing_live.status_badge'
            ) | translate
          }}</span>
        </h2>
        <p>{{ 'plans.optimizing_live.progress_label' | translate: { progress: control.progress } }}</p>
        @if (control.phaseMessage) {
          <p class="plan-optimizing__phase-message">{{ control.phaseMessage }}</p>
        }
      </section>
    </main>
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

  private _control: PlanOptimizingViewState = initialControl;
  get control(): PlanOptimizingViewState {
    return this._control;
  }
  set control(value: PlanOptimizingViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const planId = this.planId;
    if (!planId) {
      this.control = { status: 'invalid_plan_id', progress: 0, phaseMessage: '' };
      return;
    }
    this.useCase.execute({
      planId,
      onSubscribed: (ch) => {
        this.channel = ch;
      }
    });
  }

  onOptimizationCompleted(): void {
    void this.router.navigate(['/plans', this.planId]);
  }

  ngOnDestroy(): void {
    this.channel?.unsubscribe();
  }
}
