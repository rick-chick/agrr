import { Component, DestroyRef, OnInit, PLATFORM_ID, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, isPlatformServer } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { combineLatest } from 'rxjs';
import { EntryScheduleDetailView, EntryScheduleDetailViewState } from './entry-schedule-detail.view';
import { LoadEntryScheduleCropUseCase } from '../../usecase/entry-schedule/load-entry-schedule-crop.usecase';
import {
  EntryScheduleDetailPresenter,
  ENTRY_SCHEDULE_DETAIL_PROVIDERS
} from '../../adapters/entry-schedule/entry-schedule-detail.providers';
import { EntrySchedulePhaseSegment } from '../../domain/entry-schedule/entry-schedule';
import {
  MONTH_NUMBERS,
  timelineBoundsFromSummaries,
} from '../../domain/entry-schedule/entry-schedule-timeline-bounds';
import { segmentStylesForRange } from '../../domain/entry-schedule/entry-schedule-timeline-segment';
import { MasterContextHeaderComponent } from '../masters/master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../masters/master-context-header/master-context-crumb';
import { AppSeoMetaService } from '../../core/seo/app-seo-meta.service';
import {
  ENTRY_SCHEDULE_PRERENDER_CATALOG,
  findEntrySchedulePrerenderCrop,
} from '../../core/seo/entry-schedule-prerender-catalog';
import { buildEntrySchedulePrerenderSnapshot } from '../../core/seo/entry-schedule-prerender-snapshot';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { AuthService } from '../../services/auth.service';
import { Farm } from '../../domain/farms/farm';
import { displayEntryScheduleFarmName } from './entry-schedule-farm-display';

const initialControl: EntryScheduleDetailViewState = {
  loading: true,
  errorKey: null,
  data: null
};

@Component({
  selector: 'app-entry-schedule-detail',
  standalone: true,
  imports: [CommonModule, TranslateModule, MasterContextHeaderComponent, RouterLink],
  providers: [...ENTRY_SCHEDULE_DETAIL_PROVIDERS],
  template: `
    <div class="page-main public-plans-wrapper">
      <div class="free-plans-container">
        <app-master-context-header [crumbs]="contextCrumbs" />
        <div class="compact-header-card">
          <h1 class="compact-header-title">
            <span class="title-icon" aria-hidden="true">🌱</span>
            <span class="title-text">{{ 'entrySchedule.detailTitle' | translate }}</span>
          </h1>
        </div>

        @if (control.loading) {
          <section class="content-card mt-4">
            <p class="muted master-loading">{{ 'entrySchedule.loading' | translate }}</p>
          </section>
        } @else if (control.errorKey) {
          <section class="content-card mt-4">
            <p class="error-message">{{ control.errorKey | translate }}</p>
            <button type="button" class="btn btn-secondary mt-2" (click)="reload()">{{ 'entrySchedule.retry' | translate }}</button>
          </section>
        } @else if (control.data) {
          <section class="content-card mt-4" aria-labelledby="crop-name-heading">
            <div class="disclaimer-banner" role="region" aria-label="disclaimer">
              <p>{{ control.data.crop.entry_disclaimer }}</p>
            </div>

            <div class="prediction-strip es-meta-chips mt-4" role="status">
              @if (control.data.prediction.generated_at) {
                <span class="es-meta-chip"
                  >{{ 'entrySchedule.predictionFresh' | translate }}: {{ control.data.prediction.generated_at!.slice(0, 16) }}</span
                >
              }
              @if (control.data.prediction.prediction_end_date) {
                <span class="es-meta-chip"
                  >{{ 'entrySchedule.predictionUntil' | translate }}: {{ control.data.prediction.prediction_end_date!.slice(0, 10) }}</span
                >
              }
            </div>

            <h2 id="crop-name-heading" class="es-detail-hero mt-4">{{ control.data.crop.name }}</h2>
            <p class="reason-summary">{{ control.data.crop.reason_summary }}</p>
            <details class="trust-expand mt-2">
              <summary>{{ 'entrySchedule.whyTitle' | translate }}</summary>
              <pre class="reason-parts">{{ reasonPartsJson() }}</pre>
            </details>

            @if (detailGanttContext(); as gctx) {
              <div class="es-gantt-section">
                <h3 class="subsection-title">{{ 'entrySchedule.viz.ganttTitle' | translate }}</h3>
                <p class="es-gantt-intro">{{ 'entrySchedule.viz.detailGanttIntro' | translate }}</p>
                <div
                  class="es-gantt-track-wrap"
                  role="img"
                  [attr.aria-label]="'entrySchedule.viz.ganttAria' | translate: { name: control.data.crop.name }"
                >
                  <div class="es-year-banner" aria-hidden="true">
                    {{ 'entrySchedule.viz.axisYear' | translate: { year: gctx.yearLabel } }}
                  </div>
                  @if (control.data.crop.sowing_windows.length > 0) {
                    <div class="es-gantt-row">
                      <div class="es-gantt-row-label">
                        <span class="es-dot sow" aria-hidden="true"></span>
                        {{ control.data.crop.labels.sowing }}
                      </div>
                      <div class="es-gantt-track">
                        @for (w of control.data.crop.sowing_windows; track w.start_date + w.end_date) {
                          @for (seg of segmentStylesForRange(w.start_date, w.end_date, gctx); track $index) {
                            <div
                              class="es-gantt-seg sow"
                              [attr.title]="'entrySchedule.viz.bandStartHint' | translate"
                              [ngStyle]="seg"
                            ></div>
                          }
                        }
                      </div>
                    </div>
                  }
                  @if (control.data.crop.transplant_windows.length > 0) {
                    <div class="es-gantt-row">
                      <div class="es-gantt-row-label">
                        <span class="es-dot transplant" aria-hidden="true"></span>
                        {{ control.data.crop.labels.transplanting }}
                      </div>
                      <div class="es-gantt-track">
                        @for (w of control.data.crop.transplant_windows; track w.start_date + w.end_date) {
                          @for (seg of segmentStylesForRange(w.start_date, w.end_date, gctx); track $index) {
                            <div
                              class="es-gantt-seg transplant"
                              [attr.title]="'entrySchedule.viz.bandStartHint' | translate"
                              [ngStyle]="seg"
                            ></div>
                          }
                        }
                      </div>
                    </div>
                  }
                  <div class="es-month-ruler es-month-ruler--detail" aria-hidden="true">
                    @for (m of monthTicks; track m) {
                      <span class="es-month-tick">{{ 'entrySchedule.viz.monthTick' | translate: { n: m } }}</span>
                    }
                  </div>
                  <p class="es-gantt-foot">{{ 'entrySchedule.viz.detailGanttFoot' | translate }}</p>
                </div>
              </div>
            } @else {
              <h3 class="subsection-title">{{ 'entrySchedule.windows' | translate }}</h3>
              <div class="window-block">
                <h4>{{ control.data.crop.labels.sowing }}</h4>
                <ul>
                  @for (w of control.data.crop.sowing_windows; track w.start_date + w.end_date) {
                    <li>{{ w.start_date.slice(0, 10) }} – {{ w.end_date.slice(0, 10) }}</li>
                  }
                  @if (control.data.crop.sowing_windows.length === 0) {
                    <li>—</li>
                  }
                </ul>
              </div>
              <div class="window-block">
                <h4>{{ control.data.crop.labels.transplanting }}</h4>
                <ul>
                  @for (w of control.data.crop.transplant_windows; track w.start_date + w.end_date) {
                    <li>{{ w.start_date.slice(0, 10) }} – {{ w.end_date.slice(0, 10) }}</li>
                  }
                  @if (control.data.crop.transplant_windows.length === 0) {
                    <li>—</li>
                  }
                </ul>
              </div>
            }

            @if (control.data.crop.phase_segments?.length) {
              <h3 class="subsection-title">{{ 'entrySchedule.phases' | translate }}</h3>
              <div class="es-phase-rail" role="list">
                @for (p of control.data.crop.phase_segments!; track p.phase_key) {
                  <div class="es-phase-card" role="listitem">
                    <div [ngClass]="['es-phase-card-top', phaseAccentClass(p.phase_key)]"></div>
                    <div class="es-phase-title">{{ p.label }}</div>
                    @if (p.empty_reason) {
                      <p class="es-phase-empty">{{ p.empty_reason }}</p>
                    } @else if (p.start_date && p.end_date) {
                      <p class="es-phase-dates">{{ formatPhaseRange(p) }}</p>
                    }
                  </div>
                }
              </div>
            }

            @if (control.data.crop.rough_timeline?.length) {
              <h3 class="subsection-title">{{ 'entrySchedule.timeline' | translate }}</h3>
              <ul class="es-month-vtimeline">
                @for (t of control.data.crop.rough_timeline!; track t.month) {
                  <li>
                    <span class="es-month-chip">{{ t.month }}</span>
                    <div class="es-month-body">{{ t.summary }}</div>
                  </li>
                }
              </ul>
            }

            <section class="next-task mt-4" aria-labelledby="next-task-h">
              <h3 id="next-task-h" class="subsection-title">{{ 'entrySchedule.nextTask' | translate }}</h3>
              @if (control.data.crop.next_task; as nt) {
                @if (nt.available && nt.summary) {
                  <p>{{ nt.summary }}</p>
                } @else if (!nt.available && nt.summary) {
                  <p class="muted">{{ nt.summary }}</p>
                } @else {
                  <p class="muted">{{ 'entrySchedule.nextTaskPlaceholder' | translate }}</p>
                }
              } @else {
                <p class="muted">{{ 'entrySchedule.nextTaskPlaceholder' | translate }}</p>
              }
            </section>

            <h3 class="subsection-title">{{ 'entrySchedule.stages' | translate }}</h3>
            <ol class="stage-list">
              @for (s of control.data.crop.crop_stages; track s.id) {
                <li>{{ s.name }}</li>
              }
            </ol>

            <section class="es-detail-cta mt-4" aria-labelledby="es-detail-cta-heading">
              <h3 id="es-detail-cta-heading" class="subsection-title">
                {{ 'entrySchedule.ctaSectionTitle' | translate }}
              </h3>
              <div class="es-detail-cta-actions">
                <button
                  type="button"
                  class="btn btn-primary es-detail-cta-public-plan"
                  (click)="startPublicPlanWithCrop()"
                >
                  {{ 'entrySchedule.ctaPublicPlan' | translate }}
                </button>
                @if (isLoggedIn()) {
                  <a
                    class="btn btn-secondary es-detail-cta-setup"
                    [routerLink]="['/crops', control.data.crop.id, 'setup_proposal']"
                  >
                    {{ 'entrySchedule.ctaCropSetup' | translate }}
                  </a>
                }
              </div>
            </section>
          </section>
        }
      </div>
    </div>
  `,
  styleUrls: ['../public-plans/public-plan.component.css', './entry-schedule-visual.css'],
  styles: [
    `
      .subsection-title {
        font-size: 1rem;
        margin-top: 1.25rem;
        margin-bottom: 0.5rem;
      }
      .reason-summary {
        color: var(--color-text-muted);
        font-size: 0.95rem;
        margin-top: 0.5rem;
      }
      .window-block h4 {
        font-size: 0.95rem;
        margin: 0.5rem 0 0.25rem;
      }
      .window-block ul {
        margin: 0 0 0.5rem 1rem;
        padding: 0;
      }
      .stage-list {
        margin-left: 1.25rem;
      }
      .disclaimer-banner {
        padding: 0.75rem 1rem;
        background: var(--color-surface-alt);
        border-radius: 8px;
        font-size: 0.9rem;
      }
      .reason-parts {
        white-space: pre-wrap;
        font-size: 0.85rem;
        margin: 0.5rem 0 0;
      }
      .es-detail-cta-actions {
        display: flex;
        flex-wrap: wrap;
        gap: 0.75rem;
        margin-top: 0.5rem;
      }
    `
  ]
})
export class EntryScheduleDetailComponent implements EntryScheduleDetailView, OnInit {
  private readonly loadCropUseCase = inject(LoadEntryScheduleCropUseCase);
  private readonly presenter = inject(EntryScheduleDetailPresenter);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly destroyRef = inject(DestroyRef);
  private readonly platformId = inject(PLATFORM_ID);
  private readonly seo = inject(AppSeoMetaService);
  private readonly translate = inject(TranslateService);
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly auth = inject(AuthService);
  private readonly cdr = inject(ChangeDetectorRef);

  readonly monthTicks = [...MONTH_NUMBERS];
  readonly segmentStylesForRange = segmentStylesForRange;

  private _control: EntryScheduleDetailViewState = initialControl;
  get control(): EntryScheduleDetailViewState {
    return this._control;
  }
  set control(value: EntryScheduleDetailViewState) {
    this._control = value;
    this.cdr.detectChanges();
  }

  get contextCrumbs(): MasterContextCrumb[] {
    const farm = this.control.data?.farm;
    const farmId = farm?.id ?? this.resolvedFarmId();
    const cropName = this.control.data?.crop.name;
    const crumbs: MasterContextCrumb[] = [
      {
        labelKey: 'entrySchedule.title',
        routerLink:
          farmId != null ? ['/entry-schedule/farm', farmId] : ['/entry-schedule'],
      },
    ];
    if (farm) {
      crumbs.push({
        label: this.displayFarmName(farm),
        routerLink: ['/entry-schedule/farm', farm.id],
      });
    }
    crumbs.push(cropName ? { label: cropName } : { labelKey: 'entrySchedule.detailTitle' });
    return crumbs;
  }

  displayFarmName(farm: Farm): string {
    return displayEntryScheduleFarmName(farm, this.translate);
  }

  private resolvedFarmId(): number | null {
    const fromResponse = this.control.data?.farm?.id;
    if (fromResponse != null) {
      return fromResponse;
    }
    const raw = this.route.snapshot.queryParamMap.get('farmId');
    if (raw == null) {
      return null;
    }
    const parsed = Number.parseInt(raw, 10);
    return Number.isFinite(parsed) ? parsed : null;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    combineLatest([this.route.paramMap, this.route.queryParamMap])
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(() => this.fetchFromRoute());
  }

  onCropLoaded(cropId: number, cropName: string): void {
    this.seo.refreshEntryScheduleDetailMeta(cropId, cropName);
  }

  onCropLoadFailed(): void {
    this.seo.refreshEntryScheduleDetailMeta(null, null);
  }

  reasonPartsJson(): string {
    const parts = this.control.data?.crop.reason_parts;
    if (!parts) {
      return '';
    }
    try {
      return JSON.stringify(parts, null, 2);
    } catch {
      return String(parts);
    }
  }

  detailGanttContext(): { min: number; max: number; yearLabel: string } | null {
    const crop = this.control.data?.crop;
    if (!crop) {
      return null;
    }
    const phaseRanges =
      crop.phase_segments
        ?.filter((p) => p.start_date && p.end_date)
        .map((p) => ({ start_date: p.start_date!, end_date: p.end_date! })) ?? [];
    const bounds = timelineBoundsFromSummaries([
      ...crop.sowing_windows,
      ...crop.transplant_windows,
      ...phaseRanges,
    ]);
    return bounds;
  }

  phaseAccentClass(phaseKey: string): 'sowing' | 'nursery' | 'transplant' | 'harvest' {
    const m: Record<string, 'sowing' | 'nursery' | 'transplant' | 'harvest'> = {
      sowing: 'sowing',
      nursery: 'nursery',
      transplant: 'transplant',
      harvest: 'harvest'
    };
    return m[phaseKey] ?? 'nursery';
  }

  formatPhaseRange(p: EntrySchedulePhaseSegment): string {
    if (!p.start_date || !p.end_date) {
      return '';
    }
    const a = p.start_date.slice(5, 10).replace('-', '/');
    const b = p.end_date.slice(5, 10).replace('-', '/');
    return `${a} – ${b}`;
  }

  reload(): void {
    this.fetchFromRoute();
  }

  isLoggedIn(): boolean {
    return this.auth.user() != null;
  }

  startPublicPlanWithCrop(): void {
    const response = this.control.data;
    if (!response) {
      return;
    }
    const farm: Farm = {
      id: response.farm.id,
      name: response.farm.name,
      latitude: response.farm.latitude,
      longitude: response.farm.longitude,
      region: response.farm.region
    };
    this.publicPlanStore.setFarm(farm);
    this.publicPlanStore.setPendingCropId(response.crop.id);
    void this.router.navigate(['/public-plans/select-crop']);
  }

  private fetchFromRoute(): void {
    const cropId = this.route.snapshot.paramMap.get('cropId');
    const farmIdRaw = this.route.snapshot.queryParamMap.get('farmId');
    if (!cropId) {
      void this.router.navigate(['/entry-schedule']);
      return;
    }
    const cId = Number.parseInt(cropId, 10);
    if (Number.isNaN(cId)) {
      void this.router.navigate(['/entry-schedule']);
      return;
    }

    const catalogCrop = findEntrySchedulePrerenderCrop(cId);
    let farmId = farmIdRaw ? Number.parseInt(farmIdRaw, 10) : Number.NaN;
    if (Number.isNaN(farmId)) {
      if (catalogCrop) {
        farmId = ENTRY_SCHEDULE_PRERENDER_CATALOG.defaultFarmId;
      } else {
        void this.router.navigate(['/entry-schedule']);
        return;
      }
    }

    if (catalogCrop && isPlatformServer(this.platformId)) {
      const snapshot = buildEntrySchedulePrerenderSnapshot(
        catalogCrop,
        this.translate.currentLang || this.translate.defaultLang || undefined
      );
      this.control = {
        loading: false,
        errorKey: null,
        data: snapshot
      };
      this.seo.refreshEntryScheduleDetailMeta(cId, catalogCrop.name);
      return;
    }

    this.control = {
      ...this.control,
      loading: true,
      errorKey: null,
      data: null
    };

    this.loadCropUseCase.execute({ farmId, cropId: cId });
  }
}
