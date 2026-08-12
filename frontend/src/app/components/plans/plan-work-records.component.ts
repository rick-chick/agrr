import { ChangeDetectorRef, Component, DestroyRef, ElementRef, OnInit, ViewChild, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { combineLatest } from 'rxjs';
import { formatIsoDateForDisplay, formatIsoMonthForDisplay } from '../../core/format-display-date';
import {
  previewWorkRecordPhotos,
  sortedWorkRecordPhotos
} from '../../domain/plans/work-record-photo-preview';
import {
  workRecordDeltaDays,
  workRecordScheduledDate
} from '../../domain/plans/work-record-variance';
import { WorkRecord } from '../../models/plans/work-record';
import { WorkRecordPhoto } from '../../models/plans/work-record-photo';
import {
  WORK_RECORD_PHOTO_THUMB_HEIGHT_PX_HISTORY,
  WORK_RECORD_PHOTO_THUMB_WIDTH_PX_HISTORY
} from '../../domain/plans/work-record-photo.constants';
import { PlanWorkRecordsPresenter } from '../../adapters/plans/plan-work-records.presenter';
import { LoadWorkRecordsUseCase } from '../../usecase/plans/load-work-records.usecase';
import { PLAN_WORK_RECORDS_PROVIDERS } from '../../usecase/plans/plan-work-records.providers';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';
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
    PlanPlanContextHeaderComponent,
    WorkRecordSheetComponent
  ],
  providers: [...PLAN_WORK_RECORDS_PROVIDERS],
  template: `
    <div class="page-main page-main--fit">
      <app-plan-plan-context-header
        [planId]="planId"
        [planName]="control.plan?.name ?? null"
        pageTitleKey="plans.work.page_title"
      />

      <section class="section-card" aria-labelledby="plan-context-page-title">
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
          @if (!control.groups.length) {
            <div class="plan-work__empty">
              <p class="plan-work__empty-message">{{ 'plans.work_records.empty' | translate }}</p>
              <p class="plan-work__empty-hint">{{ 'plans.work_records.empty_hint' | translate }}</p>
              <a
                class="plan-work__empty-cta-link plan-work__cta--constrained"
                [routerLink]="['/plans', planId, 'work']"
              >{{ 'plans.work_records.empty_cta' | translate }}</a>
            </div>
          }

          @for (group of control.groups; track group.monthLabel) {
            <section class="plan-work-records__month">
              <h3 class="plan-work-records__month-heading">
                <span>{{ displayMonth(group.monthLabel) }}</span>
                @if (group.averageDeltaDays != null) {
                  <span class="plan-work-records__month-average">
                    {{ formatAverageDelta(group.averageDeltaDays) }}
                  </span>
                }
              </h3>
              <ul class="plan-work-records__list">
                @for (record of group.records; track record.id) {
                  <li>
                    <button type="button" class="plan-work-records__row" (click)="openEdit(record)">
                      <div class="plan-work-records__meta">
                        <span class="plan-work-records__date">{{ displayDate(record.actual_date) }}</span>
                        <span class="plan-work-records__name">{{ record.name }}</span>
                        @if (record.task_schedule_item_id) {
                          <span class="plan-work-records__badge plan-work-records__badge--scheduled">
                            {{ 'plans.work_records.badge.from_schedule' | translate }}
                          </span>
                        } @else {
                          <span class="plan-work-records__badge">{{ 'plans.work_records.badge.adhoc' | translate }}</span>
                        }
                        @if (record.field_name || record.crop_name) {
                          <span class="plan-work-records__field">
                            {{ record.field_name }} {{ record.crop_name }}
                          </span>
                        }
                        @if (record.amount) {
                          <span class="plan-work-records__amount">{{ record.amount }} {{ record.amount_unit }}</span>
                        }
                        @if (record.notes) {
                          <span class="plan-work-records__notes">{{ record.notes }}</span>
                        }
                        <div class="plan-work-records__variance">
                          @if (record.task_schedule_item_id) {
                            @if (scheduledDate(record); as scheduled) {
                              <span class="plan-work-records__variance-scheduled">
                                {{
                                  'plans.work_records.variance.scheduled'
                                    | translate: { date: displayDate(scheduled) }
                                }}
                              </span>
                              @if (deltaDays(record); as delta) {
                                <span class="plan-work-records__variance-delta">
                                  {{ formatDeltaDays(delta) }}
                                </span>
                              }
                              @if (record.gdd_at_actual != null) {
                                <span class="plan-work-records__variance-gdd">
                                  {{
                                    'plans.work_records.variance.gdd_at_actual'
                                      | translate: { value: record.gdd_at_actual }
                                  }}
                                </span>
                              }
                            }
                          } @else {
                            <span class="plan-work-records__variance-none">
                              {{ 'plans.work_records.variance.no_schedule' | translate }}
                            </span>
                          }
                        </div>
                      </div>
                      @if (record.photos?.length) {
                        <div
                          class="plan-work-records__photos"
                          (click)="$event.stopPropagation()"
                        >
                          @for (photo of previewPhotos(record); track photo.id; let i = $index) {
                            <button
                              type="button"
                              class="plan-work-records__photo-thumb"
                              [attr.aria-label]="'plans.work_records.photos.view' | translate"
                              (click)="openLightbox(record, i); $event.stopPropagation()"
                            >
                              <img
                                [src]="photo.url"
                                alt=""
                                loading="lazy"
                                decoding="async"
                                [attr.width]="thumbWidthPx"
                                [attr.height]="thumbHeightPx"
                                (error)="onPhotoUrlError()"
                              />
                            </button>
                          }
                        </div>
                      }
                    </button>
                  </li>
                }
              </ul>
            </section>
          }
        }
      </section>
    </div>

    <app-work-record-sheet
      [planId]="planId"
      (saved)="reload({ silent: true })"
      (deleted)="reload({ silent: true })"
    />

    <dialog #photoLightbox class="plan-work-records__lightbox" (cancel)="closeLightbox()">
      @if (lightboxPhotos.length) {
        <div class="plan-work-records__lightbox-shell">
          <button
            type="button"
            class="plan-work-records__lightbox-close btn btn-secondary btn-sm"
            (click)="closeLightbox()"
          >
            {{ 'plans.work_records.photos.close' | translate }}
          </button>
          @if (lightboxPhotos.length > 1) {
            <button
              type="button"
              class="plan-work-records__lightbox-prev"
              [attr.aria-label]="'plans.work_records.photos.prev' | translate"
              (click)="showPreviousPhoto()"
            >
              ‹
            </button>
            <button
              type="button"
              class="plan-work-records__lightbox-next"
              [attr.aria-label]="'plans.work_records.photos.next' | translate"
              (click)="showNextPhoto()"
            >
              ›
            </button>
          }
          <img
            class="plan-work-records__lightbox-image"
            [src]="lightboxPhotos[lightboxIndex].url"
            alt=""
            loading="eager"
            decoding="async"
            (error)="onPhotoUrlError()"
          />
        </div>
      }
    </dialog>
  `,
  styleUrls: ['./plan-work-records.component.css']
})
export class PlanWorkRecordsComponent implements PlanWorkRecordsView, OnInit {
  @ViewChild(WorkRecordSheetComponent) sheet!: WorkRecordSheetComponent;
  @ViewChild('photoLightbox') photoLightbox?: ElementRef<HTMLDialogElement>;

  private readonly route = inject(ActivatedRoute);
  private readonly loadUseCase = inject(LoadWorkRecordsUseCase);
  private readonly presenter = inject(PlanWorkRecordsPresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly translate = inject(TranslateService);
  private readonly destroyRef = inject(DestroyRef);

  lightboxPhotos: WorkRecordPhoto[] = [];
  lightboxIndex = 0;
  readonly thumbWidthPx = WORK_RECORD_PHOTO_THUMB_WIDTH_PX_HISTORY;
  readonly thumbHeightPx = WORK_RECORD_PHOTO_THUMB_HEIGHT_PX_HISTORY;

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
    combineLatest([this.route.paramMap, this.route.queryParamMap])
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(() => this.handleRouteChange());
  }

  private handleRouteChange(): void {
    if (!this.planId) {
      this.control = { ...initialControl, loading: false, error: 'plans.errors.invalid_id' };
      return;
    }
    this.reload();
  }

  reload(options?: { silent?: boolean }): void {
    if (!options?.silent) {
      this.control = { ...this.control, loading: true, error: null };
    }
    this.loadUseCase.execute({ planId: this.planId });
  }

  openEdit(record: WorkRecord): void {
    this.sheet.openEdit(record);
  }

  previewPhotos(record: WorkRecord): WorkRecordPhoto[] {
    return previewWorkRecordPhotos(record.photos);
  }

  openLightbox(record: WorkRecord, index: number): void {
    this.lightboxPhotos = sortedWorkRecordPhotos(record.photos);
    this.lightboxIndex = index;
    this.photoLightbox?.nativeElement.showModal();
    this.cdr.markForCheck();
  }

  closeLightbox(): void {
    if (this.lightboxPhotos.length) {
      this.photoLightbox?.nativeElement.close();
    }
    this.lightboxPhotos = [];
    this.lightboxIndex = 0;
    this.cdr.markForCheck();
  }

  showPreviousPhoto(): void {
    if (!this.lightboxPhotos.length) return;
    this.lightboxIndex =
      (this.lightboxIndex - 1 + this.lightboxPhotos.length) % this.lightboxPhotos.length;
    this.cdr.markForCheck();
  }

  showNextPhoto(): void {
    if (!this.lightboxPhotos.length) return;
    this.lightboxIndex = (this.lightboxIndex + 1) % this.lightboxPhotos.length;
    this.cdr.markForCheck();
  }

  onPhotoUrlError(): void {
    this.reload({ silent: true });
  }

  displayDate(iso: string): string {
    return formatIsoDateForDisplay(iso, this.translate.currentLang);
  }

  displayMonth(isoYm: string): string {
    return formatIsoMonthForDisplay(isoYm, this.translate.currentLang);
  }

  scheduledDate(record: WorkRecord): string | null {
    return workRecordScheduledDate(record);
  }

  deltaDays(record: WorkRecord): number | null {
    return workRecordDeltaDays(record);
  }

  formatDeltaDays(delta: number): string {
    if (delta > 0) {
      return this.translate.instant('plans.work_records.variance.delta_days_late', { count: delta });
    }
    if (delta < 0) {
      return this.translate.instant('plans.work_records.variance.delta_days_early', {
        count: Math.abs(delta)
      });
    }
    return this.translate.instant('plans.work_records.variance.delta_days_on_time');
  }

  formatAverageDelta(average: number): string {
    const rounded = Math.round(average);
    if (rounded > 0) {
      return this.translate.instant('plans.work_records.variance.month_average_late', {
        count: rounded
      });
    }
    if (rounded < 0) {
      return this.translate.instant('plans.work_records.variance.month_average_early', {
        count: Math.abs(rounded)
      });
    }
    return this.translate.instant('plans.work_records.variance.month_average_on_time');
  }
}
