import { Component, OnDestroy, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { Channel } from 'actioncable';
import { PublicPlanOptimizingView, PublicPlanOptimizingViewState } from './public-plan-optimizing.view';
import { SubscribePublicPlanOptimizationUseCase } from '../../usecase/public-plans/subscribe-public-plan-optimization.usecase';
import { PublicPlanOptimizingPresenter } from '../../adapters/public-plans/public-plan-optimizing.presenter';
import { SUBSCRIBE_PUBLIC_PLAN_OPTIMIZATION_OUTPUT_PORT } from '../../usecase/public-plans/subscribe-public-plan-optimization.output-port';
import { PUBLIC_PLAN_OPTIMIZATION_GATEWAY } from '../../usecase/public-plans/public-plan-optimization-gateway';
import { PublicPlanOptimizationChannelGateway } from '../../adapters/public-plans/public-plan-optimization.gateway';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';

const initialControl: PublicPlanOptimizingViewState = {
  status: 'pending',
  progress: 0,
  phaseMessage: ''
};

@Component({
  selector: 'app-public-plan-optimizing',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [
    PublicPlanOptimizingPresenter,
    SubscribePublicPlanOptimizationUseCase,
    {
      provide: SUBSCRIBE_PUBLIC_PLAN_OPTIMIZATION_OUTPUT_PORT,
      useExisting: PublicPlanOptimizingPresenter
    },
    {
      provide: PUBLIC_PLAN_OPTIMIZATION_GATEWAY,
      useClass: PublicPlanOptimizationChannelGateway
    }
  ],
  template: `
    <main class="page-main public-plans-wrapper pb-0">
      <h1 class="visually-hidden">{{ 'public_plans.title' | translate }}</h1>
      <div class="free-plans-container">
        <div class="compact-header-card">
          <div class="compact-header-title">
            <span class="title-icon" aria-hidden="true">🌱</span>
            <span class="title-text">{{ 'public_plans.title' | translate }}</span>
            <span class="status-badge optimizing">{{ 'public_plans.optimizing.status_badge' | translate }}</span>
          </div>
          <div class="compact-subtitle">
            {{ farm?.name }} · {{ 'public_plans.optimizing.crops_count' | translate: { count: selectedCropsCount } }}
          </div>
        </div>

        <div class="spacer-for-fixed-bar"></div>
      </div>
    </main>

    <div class="fixed-progress-bar">
      <div class="fixed-progress-container">
        <div class="progress-header">
          <div class="progress-label-with-spinner">
            <span class="spinner spinner-sm" [class.hidden]="control.status === 'failed'"></span>
            <div class="progress-info">
              <div class="progress-phase-message" [class.error]="control.status === 'failed'">
                {{ control.status === 'failed' ? ('public_plans.optimizing.error.title' | translate) : control.phaseMessage }}
              </div>
              <div class="progress-duration-hint">{{ 'public_plans.optimizing.progress.duration_hint' | translate }}</div>
            </div>
          </div>
          <div class="progress-elapsed-time">
            @if (elapsedTime < 60) {
              {{ 'public_plans.optimizing.progress.elapsed_time' | translate: { time: elapsedTime } }}
            } @else {
              {{ 'public_plans.optimizing.progress.elapsed_time_minute' | translate: { minutes: elapsedMinutes, seconds: elapsedSeconds } }}
            }
          </div>
        </div>

        @if (control.status === 'failed') {
          <div class="error-message-container">
            <div class="error-icon" aria-hidden="true">⚠️</div>
            <div class="error-content">
              <div class="error-title">{{ 'public_plans.optimizing.error.title' | translate }}</div>
              <div class="error-actions">
                <a [routerLink]="['/public-plans/select-crop']" class="btn btn-primary">
                  {{ 'public_plans.optimizing.error.try_again' | translate }}
                </a>
                <a [routerLink]="['/public-plans/new']" class="btn btn-secondary">
                  {{ 'public_plans.optimizing.error.start_over' | translate }}
                </a>
              </div>
            </div>
          </div>
        }
      </div>
    </div>
  `,
  styleUrl: './public-plan.component.css'
})
export class PublicPlanOptimizingComponent implements PublicPlanOptimizingView, OnInit, OnDestroy {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(SubscribePublicPlanOptimizationUseCase);
  private readonly presenter = inject(PublicPlanOptimizingPresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly cdr = inject(ChangeDetectorRef);

  elapsedTime = 0;
  private channel: Channel | null = null;
  private timer: ReturnType<typeof setInterval> | null = null;

  get elapsedMinutes(): number {
    return Math.floor(this.elapsedTime / 60);
  }
  get elapsedSeconds(): number {
    return this.elapsedTime % 60;
  }

  get farm() {
    return this.publicPlanStore.state.farm;
  }
  get selectedCropsCount() {
    return this.publicPlanStore.state.selectedCrops.length;
  }
  get planId(): number {
    return (
      Number(this.route.snapshot.queryParamMap.get('planId')) ||
      this.publicPlanStore.state.planId ||
      0
    );
  }

  private _control: PublicPlanOptimizingViewState = initialControl;
  get control(): PublicPlanOptimizingViewState {
    return this._control;
  }
  set control(value: PublicPlanOptimizingViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    if (!this.planId) {
      this.control = { ...this.control, status: 'invalid_plan_id', progress: 0, phaseMessage: '' };
      this.router.navigate(['/public-plans/new']);
      return;
    }
    this.startTimer();
    this.useCase.execute({
      planId: this.planId,
      onSubscribed: (ch) => {
        this.channel = ch;
      }
    });
  }

  onOptimizationCompleted(): void {
    this.router.navigate(['/public-plans/results'], { queryParams: { planId: this.planId } });
  }

  ngOnDestroy(): void {
    this.channel?.unsubscribe();
    this.stopTimer();
  }

  private startTimer(): void {
    this.timer = setInterval(() => {
      this.elapsedTime++;
    }, 1000);
  }

  private stopTimer(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }
}
