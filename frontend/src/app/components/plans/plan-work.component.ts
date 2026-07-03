import { ChangeDetectorRef, Component, DestroyRef, HostListener, OnInit, ViewChild, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { Channel } from 'actioncable';
import { formatIsoDateForDisplay } from '../../core/format-display-date';
import { localTodayIso } from '../../core/local-today';
import { PlanDisplayNamePipe } from '../../core/plan-display-name.pipe';
import { PlanWorkPresenter } from '../../adapters/plans/plan-work.presenter';
import { LoadWorkDayListUseCase } from '../../usecase/plans/load-work-day-list.usecase';
import { PLAN_WORK_PROVIDERS } from '../../usecase/plans/plan-work.providers';
import { SkipTaskScheduleItemUseCase } from '../../usecase/plans/skip-task-schedule-item.usecase';
import { CreateWorkRecordUseCase } from '../../usecase/plans/create-work-record.usecase';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import { PlanWorkNavComponent } from './plan-work-nav.component';
import { WorkRecordSheetSavedEvent } from './work-record-sheet.view';
import { PlanWorkView, PlanWorkViewState } from './plan-work.view';
import { WorkRecordSheetComponent } from './work-record-sheet.component';
import { TaskScheduleSyncBannerComponent } from './task-schedule-sync-banner.component';
import { RegenerateTaskScheduleUseCase } from '../../usecase/plans/regenerate-task-schedule.usecase';
import { SubscribeTaskScheduleSyncUseCase } from '../../usecase/plans/subscribe-task-schedule-sync.usecase';
import { FlashMessageService } from '../../services/flash-message.service';
import { applyPlanWorkViewEffects } from './plan-work-view.effects';

const initialControl: PlanWorkViewState = {
  loading: true,
  error: null,
  plan: null,
  fields: [],
  overdue: [],
  today: [],
  upcoming: [],
  includeSkipped: false,
  recentAdHocRecord: null,
  highlightedItemId: null,
  completingItemId: null,
  regenerating: false,
  regenerateError: null,
  pendingSyncToastKey: null,
  pendingRecordSavedToastKey: null,
  syncReloadNonce: 0
};

@Component({
  selector: 'app-plan-work',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    TranslateModule,
    PlanDisplayNamePipe,
    PlanWorkNavComponent,
    WorkRecordSheetComponent,
    TaskScheduleSyncBannerComponent
  ],
  providers: [...PLAN_WORK_PROVIDERS],
  template: `
    <main class="page-main page-main--fit">
      <header class="page-header">
        <a class="plan-work-header__back" [routerLink]="['/work']">{{
          'plans.work.back_to_hub' | translate
        }}</a>
        @if (control.plan) {
          <h1 id="plan-work-page-title" class="page-title">{{
            'plans.work.title' | translate: { name: (control.plan.name | planDisplayName) }
          }}</h1>
          <p class="page-description">
            <a class="plan-work-header__plan-link" [routerLink]="['/plans', planId]">{{
              'plans.work.back_to_plan' | translate
            }}</a>
          </p>
        }
      </header>

      <section class="section-card plan-work" aria-labelledby="plan-work-page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error plan-work__error" role="alert">
            <p>{{ control.error | translate }}</p>
            <button type="button" class="btn-secondary plan-work__retry" (click)="reload()">
              {{ 'plans.work.retry' | translate }}
            </button>
          </div>
        } @else if (control.plan) {
          <app-plan-work-nav [planId]="planId" />

          <app-task-schedule-sync-banner
            [syncState]="control.plan.task_schedule_sync_state"
            [syncError]="control.plan.task_schedule_sync_error"
            [regenerating]="control.regenerating"
            [regenerateError]="control.regenerateError"
            (retry)="regenerateTaskSchedule()"
          />

          @if (control.overdue.length) {
            <section class="plan-work__section">
              <h3 class="plan-work__section-title plan-work__section-title--overdue">
                {{ 'plans.work.section.overdue' | translate: { count: control.overdue.length } }}
              </h3>
              <ul class="plan-work__list">
                @for (row of control.overdue; track row.item.item_id) {
                  <ng-container
                    *ngTemplateOutlet="rowTpl; context: { $implicit: row, overdue: true }"
                  />
                }
              </ul>
            </section>
          }

          <section class="plan-work__section">
            <div class="plan-work__section-header">
              <h3 class="plan-work__section-title plan-work__section-title--today">{{
                'plans.work.section.today' | translate: { date: todayLabel }
              }}</h3>
              <label class="plan-work__toggle">
                <input
                  type="checkbox"
                  [checked]="control.includeSkipped"
                  (change)="toggleSkipped($event)"
                />
                {{ 'plans.work.show_skipped' | translate }}
              </label>
            </div>
            @if (control.today.length) {
              <ul class="plan-work__list">
                @for (row of control.today; track row.item.item_id) {
                  <ng-container *ngTemplateOutlet="rowTpl; context: { $implicit: row }" />
                }
              </ul>
            } @else if (control.recentAdHocRecord) {
              <div class="plan-work__recent-adhoc" role="status" aria-live="polite">
                <p class="plan-work__recent-adhoc-message">{{
                  'plans.work.recent_adhoc'
                    | translate
                      : {
                          name: control.recentAdHocRecord.name,
                          date: displayDate(control.recentAdHocRecord.actualDate)
                        }
                }}</p>
                <a
                  class="plan-work__recent-adhoc-link"
                  [routerLink]="['/plans', planId, 'work_records']"
                >{{ 'plans.work.recent_adhoc_history_link' | translate }}</a>
                <button
                  type="button"
                  class="btn-primary plan-work__empty-cta plan-work__cta--constrained"
                  (click)="openAdHoc()"
                >
                  {{ 'plans.work.add_record' | translate }}
                </button>
              </div>
            } @else {
              <div class="plan-work__empty">
                <p class="plan-work__empty-message">{{ 'plans.work.empty_today' | translate }}</p>
                <p class="plan-work__empty-hint">{{ 'plans.work.empty_today_hint' | translate }}</p>
                <button
                  type="button"
                  class="btn-primary plan-work__empty-cta plan-work__cta--constrained"
                  (click)="openAdHoc()"
                >
                  {{ 'plans.work.add_record' | translate }}
                </button>
              </div>
            }
          </section>

          @if (control.upcoming.length) {
            <section class="plan-work__section">
              <h3 class="plan-work__section-title">{{ 'plans.work.section.upcoming' | translate }}</h3>
              <ul class="plan-work__list">
                @for (row of control.upcoming; track row.item.item_id) {
                  <ng-container *ngTemplateOutlet="rowTpl; context: { $implicit: row }" />
                }
              </ul>
            </section>
          }

          @if (control.today.length) {
            <footer class="plan-work__fab">
              <button
                type="button"
                class="btn-primary plan-work__fab-btn plan-work__cta--constrained"
                (click)="openAdHoc()"
              >
                {{ 'plans.work.add_record' | translate }}
              </button>
            </footer>
          }
        }
      </section>
    </main>

    <ng-template #rowTpl let-row let-overdue="overdue">
      <li
        class="plan-work__row"
        [class.plan-work__row--done]="row.recordedToday"
        [class.plan-work__row--overdue]="overdue"
        [class.plan-work__row--highlight]="control.highlightedItemId === row.item.item_id"
      >
        <div class="plan-work__row-main">
          <span class="plan-work__date">{{ displayDate(row.item.scheduled_date) }}</span>
          <span class="plan-work__name">{{ row.item.name }}</span>
          <span class="plan-work__field">{{ row.fieldName }} {{ row.cropName }}</span>
          @if (row.recordedToday) {
            <span class="plan-work__done-badge">✓ {{ 'plans.work.recorded_today' | translate }}</span>
          }
          @if (row.item.status === 'skipped') {
            <span class="plan-work__skip-badge">{{ 'plans.work.skipped_badge' | translate }}</span>
          }
        </div>
        <div class="plan-work__row-actions">
          @if (!row.recordedToday && row.item.status !== 'skipped') {
            <button
              type="button"
              class="btn-primary plan-work__complete-btn"
              [disabled]="control.completingItemId === row.item.item_id"
              (click)="quickComplete(row)"
            >
              @if (control.completingItemId === row.item.item_id) {
                {{ 'common.loading' | translate }}
              } @else {
                {{ 'plans.work.complete' | translate }}
              }
            </button>
          }
          <button
            type="button"
            class="plan-work__menu-btn"
            [attr.aria-label]="'plans.work.menu' | translate"
            [attr.aria-expanded]="openMenuItemId === row.item.item_id"
            (click)="toggleMenu(row.item.item_id, $event)"
          >⋮</button>
          @if (openMenuItemId === row.item.item_id) {
            <div class="plan-work__menu" role="menu">
              @if (row.item.status === 'skipped') {
                <button type="button" role="menuitem" (click)="unskip(row)">
                  {{ 'plans.work.unskip' | translate }}
                </button>
              } @else {
                <button type="button" role="menuitem" (click)="openCompleteWithDetails(row)">
                  {{ 'plans.work.record_with_details' | translate }}
                </button>
                <button type="button" role="menuitem" (click)="skip(row)">
                  {{ 'plans.work.skip' | translate }}
                </button>
              }
            </div>
          }
        </div>
      </li>
    </ng-template>

    <app-work-record-sheet
      [planId]="planId"
      (saved)="onRecordSaved($event)"
      (deleted)="reload({ silent: true })"
    />
  `,
  styleUrls: ['./plan-work.component.css']
})
export class PlanWorkComponent implements PlanWorkView, OnInit {
  @ViewChild(WorkRecordSheetComponent) sheet!: WorkRecordSheetComponent;

  private readonly route = inject(ActivatedRoute);
  private readonly loadUseCase = inject(LoadWorkDayListUseCase);
  private readonly skipUseCase = inject(SkipTaskScheduleItemUseCase);
  private readonly createUseCase = inject(CreateWorkRecordUseCase);
  private readonly regenerateUseCase = inject(RegenerateTaskScheduleUseCase);
  private readonly subscribeSyncUseCase = inject(SubscribeTaskScheduleSyncUseCase);
  private readonly presenter = inject(PlanWorkPresenter);
  private readonly translate = inject(TranslateService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  openMenuItemId: number | null = null;
  private syncChannel: Channel | null = null;
  private highlightClearTimer: ReturnType<typeof setTimeout> | null = null;

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  get todayLabel(): string {
    return this.displayDate(localTodayIso());
  }

  displayDate(iso: string): string {
    return formatIsoDateForDisplay(iso, this.translate.currentLang);
  }

  private _control: PlanWorkViewState = initialControl;
  get control(): PlanWorkViewState {
    return this._control;
  }
  set control(value: PlanWorkViewState) {
    this._control = applyPlanWorkViewEffects(this._control, value, {
      flash: this.flashMessage,
      onReload: () => this.reload({ silent: true })
    });
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.presenter.onSkipSuccessCallback = () => this.reload();
    this.presenter.onRecordSavedCallback = (event) => this.onRecordSaved(event);
    this.presenter.onQuickCompleteValidationErrorCallback = (itemId, fieldErrors) => {
      const row = this.findRowByItemId(itemId);
      if (row) {
        this.sheet.openFromItem(row, { fieldErrors });
      }
    };
    this.destroyRef.onDestroy(() => {
      this.syncChannel?.unsubscribe();
      if (this.highlightClearTimer !== null) {
        clearTimeout(this.highlightClearTimer);
      }
    });
    if (!this.planId) {
      this.control = { ...initialControl, loading: false, error: 'plans.errors.invalid_id' };
      return;
    }
    this.subscribeSyncUseCase.execute({
      planId: this.planId,
      onSubscribed: (channel) => {
        this.syncChannel = channel;
      }
    });
    this.reload();
  }

  reload(options?: { silent?: boolean }): void {
    this.openMenuItemId = null;
    if (!options?.silent) {
      this.control = {
        ...this.control,
        loading: true,
        error: null,
        regenerateError: null
      };
    }
    this.loadUseCase.execute({
      planId: this.planId,
      today: localTodayIso(),
      includeSkipped: this.control.includeSkipped
    });
  }

  regenerateTaskSchedule(): void {
    this.regenerateUseCase.execute({ planId: this.planId });
  }

  onRecordSaved(event: WorkRecordSheetSavedEvent): void {
    if (event.mode === 'create-adhoc') {
      this.control = {
        ...this.control,
        recentAdHocRecord: {
          name: event.workRecord.name,
          actualDate: event.workRecord.actual_date
        },
        highlightedItemId: null
      };
    } else if (event.mode === 'create-from-item' && event.workRecord.task_schedule_item_id != null) {
      this.control = {
        ...this.control,
        recentAdHocRecord: null,
        highlightedItemId: event.workRecord.task_schedule_item_id
      };
      const itemId = event.workRecord.task_schedule_item_id;
      if (this.highlightClearTimer !== null) {
        clearTimeout(this.highlightClearTimer);
      }
      this.highlightClearTimer = setTimeout(() => {
        if (this.control.highlightedItemId === itemId) {
          this.control = { ...this.control, highlightedItemId: null };
        }
        this.highlightClearTimer = null;
      }, 3000);
    } else {
      this.control = { ...this.control, recentAdHocRecord: null };
    }
    this.reload({ silent: true });
  }

  toggleSkipped(event: Event): void {
    const checked = (event.target as HTMLInputElement).checked;
    this.control = { ...this.control, includeSkipped: checked };
    this.reload();
  }

  quickComplete(row: WorkDayListRowDto): void {
    this.openMenuItemId = null;
    this.control = { ...this.control, completingItemId: row.item.item_id, error: null };
    this.createUseCase.execute({
      planId: this.planId,
      body: {
        task_schedule_item_id: row.item.item_id,
        actual_date: localTodayIso()
      }
    });
  }

  openCompleteWithDetails(row: WorkDayListRowDto): void {
    this.openMenuItemId = null;
    this.sheet.openFromItem(row);
  }

  private findRowByItemId(itemId: number): WorkDayListRowDto | null {
    const rows = [...this.control.overdue, ...this.control.today, ...this.control.upcoming];
    return rows.find((row) => row.item.item_id === itemId) ?? null;
  }

  openAdHoc(): void {
    this.sheet.openAdHoc(this.control.fields);
  }

  toggleMenu(itemId: number, event?: Event): void {
    event?.stopPropagation();
    this.openMenuItemId = this.openMenuItemId === itemId ? null : itemId;
  }

  @HostListener('document:click', ['$event'])
  closeMenuOnOutsideClick(event: MouseEvent): void {
    if (this.openMenuItemId === null) return;
    const target = event.target as HTMLElement;
    if (target.closest('.plan-work__menu') || target.closest('.plan-work__menu-btn')) return;
    this.openMenuItemId = null;
  }

  skip(row: WorkDayListRowDto): void {
    this.openMenuItemId = null;
    this.skipUseCase.execute({ planId: this.planId, itemId: row.item.item_id, skip: true });
  }

  unskip(row: WorkDayListRowDto): void {
    this.openMenuItemId = null;
    this.skipUseCase.execute({ planId: this.planId, itemId: row.item.item_id, skip: false });
  }
}
