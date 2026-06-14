import { ChangeDetectorRef, Component, OnInit, ViewChild, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { localTodayIso } from '../../core/local-today';
import { PlanDisplayNamePipe } from '../../core/plan-display-name.pipe';
import { PlanWorkPresenter } from '../../adapters/plans/plan-work.presenter';
import { LoadWorkDayListUseCase } from '../../usecase/plans/load-work-day-list.usecase';
import { PLAN_WORK_PROVIDERS } from '../../usecase/plans/plan-work.providers';
import { SkipTaskScheduleItemUseCase } from '../../usecase/plans/skip-task-schedule-item.usecase';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import { PlanWorkNavComponent } from './plan-work-nav.component';
import { PlanWorkView, PlanWorkViewState } from './plan-work.view';
import { WorkRecordSheetComponent } from './work-record-sheet.component';

const initialControl: PlanWorkViewState = {
  loading: true,
  error: null,
  plan: null,
  fields: [],
  overdue: [],
  today: [],
  upcoming: [],
  includeSkipped: false
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
    WorkRecordSheetComponent
  ],
  providers: [...PLAN_WORK_PROVIDERS],
  template: `
    <main class="page-main page-main--fit">
      <section class="page plan-work">
        <a [routerLink]="['/plans', planId]">{{ 'plans.work.back_to_plan' | translate }}</a>

        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error" role="alert">
            <p>{{ control.error | translate }}</p>
          </div>
        } @else if (control.plan) {
          <h2>{{ 'plans.work.title' | translate: { name: (control.plan.name | planDisplayName) } }}</h2>
          <app-plan-work-nav [planId]="planId" />

          <label class="plan-work__toggle">
            <input type="checkbox" [checked]="control.includeSkipped" (change)="toggleSkipped($event)" />
            {{ 'plans.work.show_skipped' | translate }}
          </label>

          @if (control.overdue.length) {
            <section class="plan-work__section">
              <h3 class="plan-work__section-title plan-work__section-title--overdue">
                {{ 'plans.work.section.overdue' | translate: { count: control.overdue.length } }}
              </h3>
              <ul class="plan-work__list">
                @for (row of control.overdue; track row.item.item_id) {
                  <ng-container *ngTemplateOutlet="rowTpl; context: { $implicit: row }" />
                }
              </ul>
            </section>
          }

          <section class="plan-work__section">
            <h3 class="plan-work__section-title">{{ 'plans.work.section.today' | translate: { date: todayLabel } }}</h3>
            <ul class="plan-work__list">
              @for (row of control.today; track row.item.item_id) {
                <ng-container *ngTemplateOutlet="rowTpl; context: { $implicit: row }" />
              }
              @if (!control.today.length) {
                <li class="plan-work__empty">{{ 'plans.work.empty_today' | translate }}</li>
              }
            </ul>
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

          <div class="plan-work__fab">
            <button type="button" class="btn-primary" (click)="openAdHoc()">
              {{ 'plans.work.add_record' | translate }}
            </button>
          </div>
        }
      </section>
    </main>

    <ng-template #rowTpl let-row>
      <li class="plan-work__row" [class.plan-work__row--done]="row.recordedToday">
        <div class="plan-work__row-main">
          <span class="plan-work__date">{{ row.item.scheduled_date }}</span>
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
            <button type="button" class="btn-primary btn-sm" (click)="openComplete(row)">
              {{ 'plans.work.complete' | translate }}
            </button>
          }
          <button
            type="button"
            class="btn-secondary btn-sm"
            [attr.aria-label]="'plans.work.menu' | translate"
            (click)="toggleMenu(row.item.item_id)"
          >⋮</button>
          @if (openMenuItemId === row.item.item_id) {
            <div class="plan-work__menu" role="menu">
              @if (row.item.status === 'skipped') {
                <button type="button" role="menuitem" (click)="unskip(row)">
                  {{ 'plans.work.unskip' | translate }}
                </button>
              } @else {
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
      (saved)="reload()"
      (deleted)="reload()"
    />
  `,
  styleUrls: ['./plan-work.component.css']
})
export class PlanWorkComponent implements PlanWorkView, OnInit {
  @ViewChild(WorkRecordSheetComponent) sheet!: WorkRecordSheetComponent;

  private readonly route = inject(ActivatedRoute);
  private readonly loadUseCase = inject(LoadWorkDayListUseCase);
  private readonly skipUseCase = inject(SkipTaskScheduleItemUseCase);
  private readonly presenter = inject(PlanWorkPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  openMenuItemId: number | null = null;

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  get todayLabel(): string {
    return localTodayIso();
  }

  private _control: PlanWorkViewState = initialControl;
  get control(): PlanWorkViewState {
    return this._control;
  }
  set control(value: PlanWorkViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.presenter.onSkipSuccessCallback = () => this.reload();
    if (!this.planId) {
      this.control = { ...initialControl, loading: false, error: 'plans.errors.invalid_id' };
      return;
    }
    this.reload();
  }

  reload(): void {
    this.openMenuItemId = null;
    this.control = { ...this.control, loading: true };
    this.loadUseCase.execute({
      planId: this.planId,
      today: localTodayIso(),
      includeSkipped: this.control.includeSkipped
    });
  }

  toggleSkipped(event: Event): void {
    const checked = (event.target as HTMLInputElement).checked;
    this.control = { ...this.control, includeSkipped: checked };
    this.reload();
  }

  openComplete(row: WorkDayListRowDto): void {
    this.openMenuItemId = null;
    this.sheet.openFromItem(row);
  }

  openAdHoc(): void {
    this.sheet.openAdHoc(this.control.fields);
  }

  toggleMenu(itemId: number): void {
    this.openMenuItemId = this.openMenuItemId === itemId ? null : itemId;
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
