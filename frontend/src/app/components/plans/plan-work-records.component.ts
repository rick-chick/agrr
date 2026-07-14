import { ChangeDetectorRef, Component, ElementRef, OnInit, ViewChild, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { formatIsoDateForDisplay, formatIsoMonthForDisplay } from '../../core/format-display-date';
import {
  previewWorkRecordPhotos,
  sortedWorkRecordPhotos
} from '../../domain/plans/work-record-photo-preview';
import { WorkRecord } from '../../models/plans/work-record';
import { WorkRecordPhoto } from '../../models/plans/work-record-photo';
import { PlanWorkRecordsPresenter } from '../../adapters/plans/plan-work-records.presenter';
import { LoadWorkRecordsUseCase } from '../../usecase/plans/load-work-records.usecase';
import { PLAN_WORK_RECORDS_PROVIDERS } from '../../usecase/plans/plan-work-records.providers';
import { PlanWorkHeaderComponent } from './plan-work-header.component';
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
    PlanWorkHeaderComponent,
    WorkRecordSheetComponent
  ],
  providers: [...PLAN_WORK_RECORDS_PROVIDERS],
  template: `
    <main class="page-main page-main--fit">
      <app-plan-work-header [planId]="planId" [planName]="control.plan?.name ?? null" />

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
              <h3>{{ displayMonth(group.monthLabel) }}</h3>
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
    </main>

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

  lightboxPhotos: WorkRecordPhoto[] = [];
  lightboxIndex = 0;

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
}
