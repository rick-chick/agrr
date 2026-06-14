import { ChangeDetectorRef, Component, OnInit, ViewChild, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PlanDisplayNamePipe } from '../../core/plan-display-name.pipe';
import { WorkRecord } from '../../models/plans/work-record';
import { PlanWorkRecordsPresenter } from '../../adapters/plans/plan-work-records.presenter';
import { LoadWorkRecordsUseCase } from '../../usecase/plans/load-work-records.usecase';
import { PLAN_WORK_RECORDS_PROVIDERS } from '../../usecase/plans/plan-work-records.providers';
import { PlanWorkNavComponent } from './plan-work-nav.component';
import { PlanWorkRecordsView, PlanWorkRecordsViewState } from './plan-work-records.view';
import { WorkRecordSheetComponent } from './work-record-sheet.component';

const initialControl: PlanWorkRecordsViewState = {
  loading: true,
  error: null,
  plan: null,
  groups: []
};

@Component({
  selector: 'app-plan-work-records',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink,
    TranslateModule,
    PlanDisplayNamePipe,
    PlanWorkNavComponent,
    WorkRecordSheetComponent
  ],
  providers: [...PLAN_WORK_RECORDS_PROVIDERS],
  template: `
    <main class="page-main page-main--fit">
      <section class="page">
        <a [routerLink]="['/plans', planId]">{{ 'plans.work.back_to_plan' | translate }}</a>

        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error" role="alert">
            <p>{{ control.error | translate }}</p>
          </div>
        } @else if (control.plan) {
          <h2>{{ 'plans.work_records.title' | translate: { name: (control.plan.name | planDisplayName) } }}</h2>
          <app-plan-work-nav [planId]="planId" />

          @if (!control.groups.length) {
            <p class="plan-work-records__empty">{{ 'plans.work_records.empty' | translate }}</p>
          }

          @for (group of control.groups; track group.monthLabel) {
            <section class="plan-work-records__month">
              <h3>{{ group.monthLabel }}</h3>
              <ul class="plan-work-records__list">
                @for (record of group.records; track record.id) {
                  <li>
                    <button type="button" class="plan-work-records__row" (click)="openEdit(record)">
                      <span class="plan-work-records__date">{{ record.actual_date }}</span>
                      <span class="plan-work-records__name">{{ record.name }}</span>
                      @if (record.task_schedule_item_id) {
                        <span class="plan-work-records__badge plan-work-records__badge--scheduled">
                          {{ 'plans.work_records.badge.from_schedule' | translate }}
                        </span>
                      } @else {
                        <span class="plan-work-records__badge">{{ 'plans.work_records.badge.adhoc' | translate }}</span>
                      }
                      @if (record.amount) {
                        <span class="plan-work-records__amount">{{ record.amount }} {{ record.amount_unit }}</span>
                      }
                      @if (record.notes) {
                        <span class="plan-work-records__notes">{{ record.notes }}</span>
                      }
                    </button>
                  </li>
                }
              </ul>
            </section>
          }
        }
      </section>
    </main>

    <app-work-record-sheet
      [planId]="planId"
      (saved)="reload()"
      (deleted)="reload()"
    />
  `,
  styleUrls: ['./plan-work-records.component.css']
})
export class PlanWorkRecordsComponent implements PlanWorkRecordsView, OnInit {
  @ViewChild(WorkRecordSheetComponent) sheet!: WorkRecordSheetComponent;

  private readonly route = inject(ActivatedRoute);
  private readonly loadUseCase = inject(LoadWorkRecordsUseCase);
  private readonly presenter = inject(PlanWorkRecordsPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  private _control: PlanWorkRecordsViewState = initialControl;
  get control(): PlanWorkRecordsViewState {
    return this._control;
  }
  set control(value: PlanWorkRecordsViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    if (!this.planId) {
      this.control = { ...initialControl, loading: false, error: 'plans.errors.invalid_id' };
      return;
    }
    this.reload();
  }

  reload(): void {
    this.control = { ...this.control, loading: true };
    this.loadUseCase.execute({ planId: this.planId });
  }

  openEdit(record: WorkRecord): void {
    this.sheet.openEdit(record);
  }
}
