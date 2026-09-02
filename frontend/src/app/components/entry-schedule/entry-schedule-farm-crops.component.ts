import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { catchError, of, timeout } from 'rxjs';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';
import { Farm } from '../../domain/farms/farm';
import {
  EntryScheduleCropListItem,
  EntryScheduleCropsListResponse
} from '../../domain/entry-schedule/entry-schedule';
import { detectBrowserRegion } from '../../core/browser-region';
import { FlashMessageService } from '../../services/flash-message.service';
import { FunnelShellComponent } from '../shared/shells/funnel-shell.component';
import { EntryScheduleWizardProgressComponent } from './entry-schedule-wizard-progress.component';
import { MasterContextHeaderComponent } from '../masters/master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../masters/master-context-header/master-context-crumb';
import { displayEntryScheduleFarmName } from './entry-schedule-farm-display';
import { calendarYearJanDecBounds, MONTH_NUMBERS } from './entry-schedule-timeline.util';

/** entry_schedule crops API は参照作物ごとに最適化するため CI でも数十秒かかる */
const ENTRY_SCHEDULE_HTTP_TIMEOUT_MS = 60_000;
const PAGE_LIMIT = 20;

@Component({
  selector: 'app-entry-schedule-farm-crops',
  standalone: true,
  imports: [
    CommonModule,
    TranslateModule,
    RouterLink,
    FunnelShellComponent,
    EntryScheduleWizardProgressComponent,
    MasterContextHeaderComponent,
  ],
  template: `
    <div class="page-main public-plans-wrapper">
      <div class="free-plans-container">
        <app-master-context-header [crumbs]="contextCrumbs" />
        <app-funnel-shell
          variant="wizard"
          titleKey="entrySchedule.title"
          descriptionKey="pages.entry_schedule.description"
          titleIcon="📅"
        >
          <app-entry-schedule-wizard-progress ngProjectAs="[wizardProgress]" activeStep="crop" />
          @if (selectedFarm(); as farm) {
            <div class="enhanced-summary-card enhanced-summary-card--single-row">
              <div class="enhanced-summary-items">
                <div class="enhanced-summary-row">
                  <div class="enhanced-summary-icon">🌏</div>
                  <div class="enhanced-summary-content">
                    <div class="enhanced-summary-label">{{ 'entrySchedule.summary.farm' | translate }}</div>
                    <div class="enhanced-summary-value">{{ displayFarmName(farm) }}</div>
                  </div>
                </div>
              </div>
            </div>
          }
          <section class="content-card" aria-labelledby="entry-schedule-crops-heading">
            <h2 id="entry-schedule-crops-heading" class="visually-hidden">
              {{ 'entrySchedule.selectFarm' | translate }}
            </h2>

            @if (farmLoading()) {
              <p class="muted master-loading">{{ 'entrySchedule.loading' | translate }}</p>
            } @else if (cropsLoading()) {
              <p class="muted mt-4 master-loading">{{ 'entrySchedule.loading' | translate }}</p>
            } @else if (cropsError()) {
              <p class="error-message mt-4">{{ cropsError()! | translate }}</p>
              <button type="button" class="btn btn-secondary mt-2" (click)="loadCrops(false)">
                {{ 'entrySchedule.retry' | translate }}
              </button>
            } @else if (listResponse()) {
              @if (listEmptyKind(); as emptyKind) {
                <div class="es-list-empty" role="status">
                  <h3 class="es-list-empty-title">
                    {{ 'entrySchedule.listEmpty.' + emptyKind + '.title' | translate }}
                  </h3>
                  <p class="es-list-empty-description">
                    {{ 'entrySchedule.listEmpty.' + emptyKind + '.description' | translate }}
                  </p>
                  <p class="es-list-empty-hint">
                    {{ 'entrySchedule.listEmpty.' + emptyKind + '.hint' | translate }}
                  </p>
                  <a routerLink="/crops" class="btn btn-primary es-list-empty-action">
                    {{ 'entrySchedule.listEmpty.' + emptyKind + '.action' | translate }}
                  </a>
                </div>
              } @else {
                <div class="entry-schedule-meta muted mt-4" role="status">
                  @if (listResponse()!.prediction.generated_at) {
                    <span class="meta-line"
                      >{{ 'entrySchedule.predictionFresh' | translate }}:
                      {{ listResponse()!.prediction.generated_at | slice: 0 : 16 }}</span
                    >
                  }
                  @if (listResponse()!.prediction.prediction_end_date) {
                    <span class="meta-line"
                      >{{ 'entrySchedule.predictionUntil' | translate }}:
                      {{ listResponse()!.prediction.prediction_end_date | slice: 0 : 10 }}</span
                    >
                  }
                </div>
                <div class="es-crop-grid" role="list">
                  @for (c of listResponse()!.crops; track c.id; let idx = $index) {
                    <article
                      class="es-crop-card"
                      [class.ineligible]="!c.eligible"
                      role="listitem"
                      [attr.aria-label]="c.name"
                    >
                      <div class="es-crop-head">
                        <span class="eligible-pill" [attr.data-state]="c.eligible ? 'ok' : 'no'">
                          {{
                            c.eligible
                              ? ('entrySchedule.eligibleYes' | translate)
                              : ('entrySchedule.eligibleNo' | translate)
                          }}
                        </span>
                        <span class="es-crop-name">{{ c.name }}</span>
                      </div>
                      <p class="es-flow-line">{{ c.schedule_flow_summary || '—' }}</p>

                      @if (chartTimelineContext(c); as ctx) {
                        <div
                          class="es-mini-chart"
                          role="img"
                          [attr.aria-label]="'entrySchedule.viz.ganttAria' | translate: { name: c.name }"
                        >
                          <p class="es-mini-chart-intro">{{ 'entrySchedule.viz.listChartIntro' | translate }}</p>
                          <div class="es-year-banner" aria-hidden="true">
                            {{ 'entrySchedule.viz.axisYear' | translate: { year: ctx.year } }}
                          </div>
                          <div class="es-mini-rows">
                            <div class="es-mini-row">
                              <span class="es-mini-row-label">{{ 'entrySchedule.viz.sowBand' | translate }}</span>
                              <div class="es-track">
                                @if (c.sowing_summary) {
                                  <div
                                    class="es-seg sow"
                                    [attr.title]="'entrySchedule.viz.bandStartHint' | translate"
                                    [ngStyle]="
                                      segmentStyle(c.sowing_summary.start_date, c.sowing_summary.end_date, ctx)
                                    "
                                  ></div>
                                }
                              </div>
                            </div>
                            <div class="es-mini-row">
                              <span class="es-mini-row-label">{{
                                'entrySchedule.viz.transplantBand' | translate
                              }}</span>
                              <div class="es-track">
                                @if (c.transplant_summary) {
                                  <div
                                    class="es-seg transplant"
                                    [attr.title]="'entrySchedule.viz.bandStartHint' | translate"
                                    [ngStyle]="
                                      segmentStyle(
                                        c.transplant_summary.start_date,
                                        c.transplant_summary.end_date,
                                        ctx
                                      )
                                    "
                                  ></div>
                                }
                              </div>
                            </div>
                          </div>
                          <div class="es-month-ruler" aria-hidden="true">
                            @for (m of monthTicks; track m) {
                              <span class="es-month-tick">{{
                                'entrySchedule.viz.monthTick' | translate: { n: m }
                              }}</span>
                            }
                          </div>
                          <p class="es-mini-chart-foot">{{ 'entrySchedule.viz.listChartFoot' | translate }}</p>
                        </div>
                      } @else {
                        <div class="es-crop-card-empty" role="status">
                          <span class="es-crop-card-empty-icon" aria-hidden="true">📅</span>
                          <p class="es-crop-card-empty-message">
                            {{ 'entrySchedule.viz.noWindowTitle' | translate }}
                          </p>
                          <p class="es-crop-card-empty-hint">
                            {{ 'entrySchedule.viz.noWindowHint' | translate }}
                          </p>
                        </div>
                      }

                      <div class="es-date-pills">
                        @if (c.sowing_summary) {
                          <span class="es-pill sow">{{ formatRangeShort(c.sowing_summary) }}</span>
                        }
                        @if (c.transplant_summary) {
                          <span class="es-pill transplant">{{ formatRangeShort(c.transplant_summary) }}</span>
                        }
                      </div>

                      @if (c.schedule_flow_detail) {
                        <div class="es-expand-wrap">
                          <button
                            type="button"
                            class="btn-link"
                            (click)="toggleFlowDetail(idx)"
                            [attr.aria-expanded]="flowDetailOpen().has(idx)"
                          >
                            {{
                              flowDetailOpen().has(idx)
                                ? ('entrySchedule.collapse' | translate)
                                : ('entrySchedule.expand' | translate)
                            }}
                          </button>
                        </div>
                      }
                      @if (flowDetailOpen().has(idx) && c.schedule_flow_detail) {
                        <div class="flow-detail-expanded">
                          <p class="flow-detail">{{ c.schedule_flow_detail }}</p>
                          <p class="reason-trust">
                            <strong>{{ 'entrySchedule.whyTitle' | translate }}</strong>
                            {{ c.reason_summary }}
                          </p>
                        </div>
                      }

                      <div class="es-card-actions">
                        <a
                          [routerLink]="['/entry-schedule/crop', c.id]"
                          [queryParams]="detailQueryParams()"
                          class="link-inline es-link-detail"
                        >
                          {{ 'entrySchedule.table.detail' | translate }} →
                        </a>
                      </div>
                    </article>
                  }
                </div>
                @if (listResponse()!.meta.has_more) {
                  <div class="mt-4">
                    <button
                      type="button"
                      class="btn btn-secondary"
                      [disabled]="cropsLoading()"
                      (click)="loadCrops(true)"
                    >
                      {{ 'entrySchedule.loadMore' | translate }}
                    </button>
                  </div>
                }
                <p class="footer-disclaimer muted mt-4">{{ 'entrySchedule.listDisclaimer' | translate }}</p>
              }
            }
          </section>
        </app-funnel-shell>
      </div>
    </div>
  `,
  styleUrls: [
    '../shared/shells/funnel-shell.component.css',
    '../public-plans/public-plan.component.css',
    './entry-schedule-visual.css'
  ],
  styles: [
    `
      .visually-hidden {
        position: absolute;
        width: 1px;
        height: 1px;
        padding: 0;
        margin: -1px;
        overflow: hidden;
        clip: rect(0, 0, 0, 0);
        border: 0;
      }
      .flow-detail-expanded {
        margin-top: 0.75rem;
        padding: 0.75rem;
        background: var(--color-surface-alt);
        border-radius: 10px;
        font-size: 0.88rem;
      }
      .reason-trust {
        margin-top: 0.5rem;
      }
      .meta-line {
        display: block;
      }
      .btn-link {
        background: none;
        border: none;
        color: var(--color-link);
        cursor: pointer;
        text-decoration: underline;
        padding: 0;
        font-size: 0.85rem;
      }
      .footer-disclaimer {
        font-size: 0.85rem;
      }
    `
  ]
})
export class EntryScheduleFarmCropsComponent implements OnInit {
  private readonly gateway = inject(ENTRY_SCHEDULE_GATEWAY);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly flash = inject(FlashMessageService);
  private readonly translate = inject(TranslateService);

  readonly monthTicks = [...MONTH_NUMBERS];

  readonly farmLoading = signal(true);
  readonly selectedFarmId = signal<number | null>(null);
  readonly selectedFarm = signal<Farm | null>(null);

  readonly listResponse = signal<EntryScheduleCropsListResponse | null>(null);
  readonly cropsLoading = signal(false);
  readonly cropsError = signal<string | null>(null);
  readonly flowDetailOpen = signal<Set<number>>(new Set());

  private loadCursor: string | null = null;

  get contextCrumbs(): MasterContextCrumb[] {
    const farm = this.selectedFarm();
    return [
      { labelKey: 'entrySchedule.title', routerLink: ['/entry-schedule'] },
      farm
        ? { label: this.displayFarmName(farm) }
        : { labelKey: 'entrySchedule.steps.crop' },
    ];
  }

  displayFarmName(farm: Farm): string {
    return displayEntryScheduleFarmName(farm, this.translate);
  }

  ngOnInit(): void {
    const rawFarmId = this.route.snapshot.paramMap.get('farmId');
    const farmId = rawFarmId != null ? Number(rawFarmId) : NaN;
    if (!Number.isFinite(farmId) || farmId <= 0) {
      this.redirectInvalidFarm();
      return;
    }
    this.resolveFarm(farmId);
  }

  private redirectInvalidFarm(): void {
    this.flash.show({ type: 'warning', text: 'entrySchedule.invalid_farm_id' });
    void this.router.navigate(['/entry-schedule'], { replaceUrl: true });
  }

  private resolveFarm(farmId: number): void {
    const region = detectBrowserRegion();
    this.farmLoading.set(true);
    this.gateway
      .getEntryScheduleFarms(region)
      .pipe(
        timeout(ENTRY_SCHEDULE_HTTP_TIMEOUT_MS),
        catchError(() => of([] as Farm[]))
      )
      .subscribe((rows) => {
        this.farmLoading.set(false);
        const farm = rows.find((row) => row.id === farmId);
        if (!farm) {
          this.redirectInvalidFarm();
          return;
        }
        this.selectedFarmId.set(farm.id);
        this.selectedFarm.set(farm);
        this.loadCrops(false);
      });
  }

  detailQueryParams(): Record<string, string | number> {
    const farmId = this.listResponse()?.farm.id ?? this.selectedFarmId();
    const q: Record<string, string | number> = {};
    if (farmId != null) {
      q['farmId'] = farmId;
    }
    return q;
  }

  toggleFlowDetail(idx: number): void {
    const next = new Set(this.flowDetailOpen());
    if (next.has(idx)) {
      next.delete(idx);
    } else {
      next.add(idx);
    }
    this.flowDetailOpen.set(next);
  }

  loadCrops(append: boolean): void {
    const farmId = this.selectedFarmId();
    if (farmId == null) {
      return;
    }
    this.cropsLoading.set(true);
    this.cropsError.set(null);
    if (!append) {
      this.listResponse.set(null);
      this.loadCursor = null;
    }
    this.gateway
      .getEntryScheduleCrops(farmId, {
        limit: PAGE_LIMIT,
        cursor: append ? this.loadCursor : undefined
      })
      .pipe(
        timeout(ENTRY_SCHEDULE_HTTP_TIMEOUT_MS),
        catchError((err: unknown) => {
          const name = err && typeof err === 'object' && 'name' in err ? String((err as { name: string }).name) : '';
          this.cropsError.set(name === 'TimeoutError' ? 'entrySchedule.timeout' : 'entrySchedule.error');
          return of(null as EntryScheduleCropsListResponse | null);
        })
      )
      .subscribe((res) => {
        this.cropsLoading.set(false);
        if (!res) {
          return;
        }
        this.loadCursor = res.meta?.next_cursor ?? null;
        if (append && this.listResponse()) {
          const prev = this.listResponse()!;
          const merged: EntryScheduleCropListItem[] = [...prev.crops, ...res.crops];
          this.listResponse.set({
            ...res,
            crops: merged,
            farm: res.farm,
            prediction: res.prediction,
            meta: res.meta
          });
        } else {
          this.listResponse.set(res);
        }
      });
  }

  chartTimelineContext(c: EntryScheduleCropListItem): { min: number; max: number; year: number } | null {
    if (!c.sowing_summary && !c.transplant_summary) {
      return null;
    }
    const y = this.listResponse()?.prediction?.chart_calendar_year ?? new Date().getFullYear();
    return calendarYearJanDecBounds(y);
  }

  segmentStyle(startIso: string, endIso: string, ctx: { min: number; max: number }): Record<string, string> {
    const t0 = Date.parse(startIso);
    const t1 = Date.parse(endIso);
    const span = ctx.max - ctx.min;
    if (!Number.isFinite(t0) || !Number.isFinite(t1) || !Number.isFinite(span) || span <= 0) {
      return { display: 'none' };
    }
    const leftRaw = ((t0 - ctx.min) / span) * 100;
    const rightRaw = ((t1 - ctx.min) / span) * 100;
    const left = Math.max(0, Math.min(100, leftRaw));
    const right = Math.max(0, Math.min(100, rightRaw));
    const width = Math.max(0.5, right - left);
    return {
      left: `${left}%`,
      width: `${width}%`
    };
  }

  formatRangeShort(summary: { start_date: string; end_date: string }): string {
    const a = summary.start_date.slice(5, 10).replace('-', '/');
    const b = summary.end_date.slice(5, 10).replace('-', '/');
    return `${a} – ${b}`;
  }

  listEmptyKind(): 'noCrops' | 'allIneligible' | null {
    const res = this.listResponse();
    if (!res) {
      return null;
    }
    if (res.crops.length === 0) {
      return 'noCrops';
    }
    if (res.crops.every((crop) => !crop.eligible) && !res.meta?.has_more) {
      return 'allIneligible';
    }
    return null;
  }
}
