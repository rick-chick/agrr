import { Component, DestroyRef, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { Channel } from 'actioncable';
import { PlanDisplayNamePipe } from '../../core/plan-display-name.pipe';
import { TaskScheduleTimelineComponent } from './task-schedule-timeline.component';
import { PlanTaskScheduleView, PlanTaskScheduleViewState } from './plan-task-schedule.view';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { PlanTaskSchedulePresenter, PLAN_TASK_SCHEDULE_PROVIDERS } from '../../usecase/plans/plan-task-schedule.providers';
import { PlanWorkNavComponent } from './plan-work-nav.component';
import { TaskScheduleSyncBannerComponent } from './task-schedule-sync-banner.component';
import { RegenerateTaskScheduleUseCase } from '../../usecase/plans/regenerate-task-schedule.usecase';
import { SubscribeTaskScheduleSyncUseCase } from '../../usecase/plans/subscribe-task-schedule-sync.usecase';
import { FlashMessageService } from '../../services/flash-message.service';
import { applyTaskScheduleSyncViewEffects } from './task-schedule-sync-view.effects';

const initialControl: PlanTaskScheduleViewState = {
  loading: true,
  error: null,
  schedule: null,
  regenerating: false,
  regenerateError: null,
  pendingSyncToastKey: null,
  syncReloadNonce: 0
};

@Component({
  selector: 'app-plan-task-schedule',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    TaskScheduleTimelineComponent,
    TranslateModule,
    PlanDisplayNamePipe,
    PlanWorkNavComponent,
    TaskScheduleSyncBannerComponent
  ],
  providers: [...PLAN_TASK_SCHEDULE_PROVIDERS],
  template: `
    <main class="page-main page-main--fit">
      <header class="page-header">
        <a class="plan-work-header__back" [routerLink]="['/work']">{{
          'plans.work.back_to_hub' | translate
        }}</a>
        @if (control.schedule) {
          <h1 id="plan-work-page-title" class="page-title">{{
            'plans.task_schedules.title'
              | translate: { name: (control.schedule.plan.name | planDisplayName) }
          }}</h1>
          <p class="page-description">
            <a class="plan-work-header__plan-link" [routerLink]="['/plans', planId]">{{
              'plans.task_schedules.back_to_plan' | translate
            }}</a>
          </p>
        }
      </header>

      <section class="section-card" aria-labelledby="plan-work-page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error plan-work__error" role="alert">
            <p>{{ control.error | translate }}</p>
            <button type="button" class="btn-secondary plan-work__retry" (click)="reload()">
              {{ 'plans.work.retry' | translate }}
            </button>
          </div>
        } @else if (control.schedule) {
          <app-plan-work-nav [planId]="planId" />
          <app-task-schedule-sync-banner
            [syncState]="control.schedule.plan.task_schedule_sync_state"
            [syncError]="control.schedule.plan.task_schedule_sync_error"
            [regenerating]="control.regenerating"
            [regenerateError]="control.regenerateError"
            (retry)="regenerateTaskSchedule()"
          />
          <app-task-schedule-timeline [fields]="control.schedule.fields" />
        }
      </section>
    </main>
  `,
  styleUrls: ['./plan-task-schedule.component.css']
})
export class PlanTaskScheduleComponent implements PlanTaskScheduleView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadPlanTaskScheduleUseCase);
  private readonly regenerateUseCase = inject(RegenerateTaskScheduleUseCase);
  private readonly subscribeSyncUseCase = inject(SubscribeTaskScheduleSyncUseCase);
  private readonly presenter = inject(PlanTaskSchedulePresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  private syncChannel: Channel | null = null;

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  private _control: PlanTaskScheduleViewState = initialControl;
  get control(): PlanTaskScheduleViewState {
    return this._control;
  }
  set control(value: PlanTaskScheduleViewState) {
    this._control = applyTaskScheduleSyncViewEffects(this._control, value, {
      flash: this.flashMessage,
      onReload: () => this.reload({ silent: true })
    });
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.destroyRef.onDestroy(() => {
      this.syncChannel?.unsubscribe();
    });
    const planId = this.planId;
    if (!planId) {
      this.control = { ...initialControl, loading: false, error: 'plans.errors.invalid_id' };
      return;
    }
    this.subscribeSyncUseCase.execute({
      planId,
      onSubscribed: (channel) => {
        this.syncChannel = channel;
      }
    });
    this.reload();
  }

  reload(options?: { silent?: boolean }): void {
    const planId = this.planId;
    if (!planId) {
      this.control = { ...initialControl, loading: false, error: 'plans.errors.invalid_id' };
      return;
    }
    if (!options?.silent) {
      this.control = { ...this.control, loading: true, error: null, regenerateError: null };
    }
    this.useCase.execute({ planId });
  }

  regenerateTaskSchedule(): void {
    this.regenerateUseCase.execute({ planId: this.planId });
  }
}
