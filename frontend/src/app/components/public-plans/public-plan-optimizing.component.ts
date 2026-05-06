import {
  ChangeDetectorRef,
  Component,
  NgZone,
  OnDestroy,
  OnInit,
  inject
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { Channel } from 'actioncable';
import { PublicPlanOptimizingView, PublicPlanOptimizingViewState } from './public-plan-optimizing.view';
import { SubscribePublicPlanOptimizationUseCase } from '../../usecase/public-plans/subscribe-public-plan-optimization.usecase';
import {
  PublicPlanOptimizingPresenter,
  PUBLIC_PLAN_OPTIMIZING_PROVIDERS
} from '../../usecase/public-plans/public-plan-optimizing.providers';
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
  providers: [...PUBLIC_PLAN_OPTIMIZING_PROVIDERS],
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
                @if (control.status !== 'failed') {
                  {{
                    control.phaseMessage ||
                      ('public_plans.optimizing.progress.default_message' | translate)
                  }}
                }
              </div>
              @if (control.status !== 'failed') {
                <div class="progress-duration-hint">{{ 'public_plans.optimizing.progress.duration_hint' | translate }}</div>
              }
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
              @if (control.phaseMessage) {
                <div class="error-detail">{{ control.phaseMessage }}</div>
              }
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
  styleUrls: ['./public-plan.component.css']
})
export class PublicPlanOptimizingComponent implements PublicPlanOptimizingView, OnInit, OnDestroy {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(SubscribePublicPlanOptimizationUseCase);
  private readonly presenter = inject(PublicPlanOptimizingPresenter);
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly ngZone = inject(NgZone);

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
  /** snapshot は遅延ルート初回描画でクエリ未確定になりうるため、初期化は queryParamMap で行う */
  private resolvedPlanId = 0;

  get planId(): number {
    return (
      this.resolvedPlanId ||
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
    const pid = this.resolvePlanIdFromNavigation();
    this.resolvedPlanId = pid;
    if (!pid) {
      this.control = { ...this.control, status: 'invalid_plan_id', progress: 0, phaseMessage: '' };
      void this.router.navigate(['/public-plans/new']);
      return;
    }
    this.cdr.markForCheck();
    this.startTimer();
    this.useCase.execute({
      planId: pid,
      onSubscribed: (ch) => {
        this.channel = ch;
      }
    });
  }

  /** Playwright 直叩き・遅延ルートとも整合するよう URL とストアの両方から解決する */
  private resolvePlanIdFromNavigation(): number {
    try {
      const q = new URLSearchParams(globalThis.location?.search ?? '');
      const raw = q.get('planId');
      const fromUrl = raw !== null && raw !== '' ? Number(raw) : NaN;
      if (!Number.isNaN(fromUrl) && fromUrl > 0) {
        return fromUrl;
      }
    } catch {
      /* location が無い環境ではフォールバックへ */
    }
    const fromSnapshot = Number(this.route.snapshot.queryParamMap.get('planId'));
    if (!Number.isNaN(fromSnapshot) && fromSnapshot > 0) {
      return fromSnapshot;
    }
    const fromStore = this.publicPlanStore.state.planId;
    return fromStore && fromStore > 0 ? fromStore : 0;
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
      // Zone 外で setInterval が動く環境と、Default 戦略で markForCheck が自身に無効な点の両方を潰す
      this.ngZone.run(() => {
        this.elapsedTime++;
        this.cdr.detectChanges();
      });
    }, 1000);
  }

  private stopTimer(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }
}
