import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { catchError, of, timeout } from 'rxjs';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';
import { Farm } from '../../domain/farms/farm';
import {
  EntryScheduleCropListItem,
  EntryScheduleCropsListResponse
} from '../../domain/entry-schedule/entry-schedule';
import { detectBrowserRegion } from '../../core/browser-region';
import { calendarYearJanDecBounds, MONTH_NUMBERS } from './entry-schedule-timeline.util';
import { FunnelShellComponent } from '../shared/shells/funnel-shell.component';
import { FarmSelectionCardsPattern } from '../shared/patterns/farm-selection-cards.pattern';

const ENTRY_SCHEDULE_HTTP_TIMEOUT_MS = 25_000;
const PAGE_LIMIT = 20;

@Component({
  selector: 'app-entry-schedule-list',
  standalone: true,
  imports: [CommonModule, TranslateModule, RouterLink, FunnelShellComponent, FarmSelectionCardsPattern],
  template: `
    <div class="page-main public-plans-wrapper">
      <div class="free-plans-container">
        <app-funnel-shell
          variant="hub"
          titleKey="entrySchedule.title"
          descriptionKey="pages.entry_schedule.description"
          titleIcon="📅"
        >
          <section class="content-card" aria-labelledby="entry-schedule-heading">
            <h2 id="entry-schedule-heading" class="section-heading">
              {{ 'entrySchedule.selectFarm' | translate }}
            </h2>
            <app-farm-selection-cards
              [state]="farmCardsState()"
              [farms]="farms()"
              [selectedFarmId]="selectedFarmId()"
              [errorKey]="farmsError() ?? 'entrySchedule.error'"
              (farmSelect)="onFarmSelected($event)"
              (retry)="retryFarms()"
            />

            @if (selectedFarmId() == null && farms().length > 0 && farmCardsState() === 'ready') {
              <p class="placeholder-block mt-4">{{ 'entrySchedule.blockSelectFarm' | translate }}</p>
            }

            @if (cropsLoading()) {
              <p class="muted mt-4 master-loading">{{ 'entrySchedule.loading' | translate }}</p>
            } @else if (cropsError()) {
              <p class="error-message mt-4">{{ cropsError()! | translate }}</p>
              <button type="button" class="btn btn-secondary mt-2" (click)="loadCrops(false)">
                {{ 'entrySchedule.retry' | translate }}
              </button>
            } @else if (listResponse()) {
              <div class="entry-schedule-meta muted mt-4" role="status">
                @if (listResponse()!.prediction.generated_at) {
                  <span class="meta-line"
                    >{{ 'entrySchedule.predictionFresh' | translate }}:
                    {{ listResponse()!.prediction.generated_at | slice: 0 : 16 }}</span
                  >
                }
                @if (listResponse()!.prediction.prediction_end_date) {
                  <span class="meta-line">{{ 'entrySchedule.predictionUntil' | translate }}: {{ listResponse()!.prediction.prediction_end_date | slice: 0 : 10 }}</span>
                }
              </div>
              @if (isAllIneligibleEmpty(listResponse()!)) {
                <section
                  class="es-all-ineligible-empty mt-4"
                  data-testid="entry-schedule-all-ineligible"
                  aria-labelledby="es-all-ineligible-title"
                >
                  <h3 id="es-all-ineligible-title">{{ 'entrySchedule.allIneligibleTitle' | translate }}</h3>
                  <p>{{ 'entrySchedule.allIneligibleBody' | translate }}</p>
                  <div class="es-all-ineligible-actions">
                    <p class="muted">{{ 'entrySchedule.allIneligibleTryOtherFarm' | translate }}</p>
                    <a routerLink="/public-plans/new" class="btn btn-primary">
                      {{ 'entrySchedule.allIneligiblePublicPlanCta' | translate }}
                    </a>
                  </div>
                </section>
              } @else {
              <div class="es-crop-grid" data-testid="entry-schedule-crop-grid" role="list">
                @for (c of listResponse()!.crops; track c.id; let idx = $index) {
                  <article
                    class="es-crop-card"
                    [class.ineligible]="!c.eligible"
                    role="listitem"
                    [attr.aria-label]="c.name"
                  >
                    <div class="es-crop-head">
                      <span class="eligible-pill" [attr.data-state]="c.eligible ? 'ok' : 'no'">
                        {{ c.eligible ? ('entrySchedule.eligibleYes' | translate) : ('entrySchedule.eligibleNo' | translate) }}
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
                                  [ngStyle]="segmentStyle(c.sowing_summary.start_date, c.sowing_summary.end_date, ctx)"
                                ></div>
                              }
                            </div>
                          </div>
                          <div class="es-mini-row">
                            <span class="es-mini-row-label">{{ 'entrySchedule.viz.transplantBand' | translate }}</span>
                            <div class="es-track">
                              @if (c.transplant_summary) {
                                <div
                                  class="es-seg transplant"
                                  [attr.title]="'entrySchedule.viz.bandStartHint' | translate"
                                  [ngStyle]="segmentStyle(c.transplant_summary.start_date, c.transplant_summary.end_date, ctx)"
                                ></div>
                              }
                            </div>
                          </div>
                        </div>
                        <div class="es-month-ruler" aria-hidden="true">
                          @for (m of monthTicks; track m) {
                            <span class="es-month-tick">{{ 'entrySchedule.viz.monthTick' | translate: { n: m } }}</span>
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
                          {{ flowDetailOpen().has(idx) ? ('entrySchedule.collapse' | translate) : ('entrySchedule.expand' | translate) }}
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
              }
              @if (listResponse()!.meta.has_more && !isAllIneligibleEmpty(listResponse()!)) {
                <div class="mt-4">
                  <button type="button" class="btn btn-secondary" [disabled]="cropsLoading()" (click)="loadCrops(true)">
                    {{ 'entrySchedule.loadMore' | translate }}
                  </button>
                </div>
              }
              <p class="footer-disclaimer muted mt-4">{{ 'entrySchedule.listDisclaimer' | translate }}</p>
            }
          </section>
        </app-funnel-shell>
      </div>
    </div>
  `,
  styleUrls: ['../shared/shells/funnel-shell.component.css', '../public-plans/public-plan.component.css', './entry-schedule-visual.css'],
  styles: [
    `
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
      .section-heading {
        font-size: 1.1rem;
        margin-bottom: 1rem;
      }
      .placeholder-block {
        padding: 1.5rem;
        border: 1px dashed var(--color-border);
        border-radius: 8px;
        text-align: center;
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
      .es-all-ineligible-empty {
        padding: 1.5rem;
        border: 1px solid var(--color-border);
        border-radius: var(--radius-lg);
        background: var(--color-surface);
      }
      .es-all-ineligible-empty h3 {
        margin: 0 0 0.5rem;
        font-size: 1.05rem;
      }
      .es-all-ineligible-actions {
        display: flex;
        flex-direction: column;
        gap: 0.75rem;
        margin-top: 1rem;
      }
    `
  ]
})
export class EntryScheduleListComponent implements OnInit {
  private readonly gateway = inject(ENTRY_SCHEDULE_GATEWAY);

  /** 1月〜12月の目盛り用 */
  readonly monthTicks = [...MONTH_NUMBERS];

  readonly farms = signal<Farm[]>([]);
  readonly farmsLoading = signal(true);
  readonly farmsError = signal<string | null>(null);

  readonly selectedFarmId = signal<number | null>(null);

  readonly listResponse = signal<EntryScheduleCropsListResponse | null>(null);
  readonly cropsLoading = signal(false);
  readonly cropsError = signal<string | null>(null);
  readonly flowDetailOpen = signal<Set<number>>(new Set());

  private loadCursor: string | null = null;

  farmCardsState(): 'loading' | 'empty' | 'error' | 'ready' {
    if (this.farmsLoading()) {
      return 'loading';
    }
    if (this.farmsError()) {
      return 'error';
    }
    if (this.farms().length === 0) {
      return 'empty';
    }
    return 'ready';
  }

  ngOnInit(): void {
    this.loadFarmsList();
  }

  private loadFarmsList(): void {
    const region = detectBrowserRegion();
    this.farmsError.set(null);
    this.farmsLoading.set(true);
    this.gateway
      .getEntryScheduleFarms(region)
      .pipe(
        timeout(ENTRY_SCHEDULE_HTTP_TIMEOUT_MS),
        catchError((err: unknown) => {
          const name = err && typeof err === 'object' && 'name' in err ? String((err as { name: string }).name) : '';
          if (name === 'TimeoutError') {
            this.farmsError.set('entrySchedule.timeout');
          } else {
            this.farmsError.set('entrySchedule.error');
          }
          return of([] as Farm[]);
        })
      )
      .subscribe((rows) => {
        this.farms.set(rows);
        this.farmsLoading.set(false);
        if (rows.length === 1) {
          this.selectedFarmId.set(rows[0].id);
          this.loadCrops(false);
        }
      });
  }

  retryFarms(): void {
    this.farmsLoading.set(true);
    this.loadFarmsList();
  }

  onFarmSelected(farm: Farm): void {
    this.selectedFarmId.set(farm.id);
    this.listResponse.set(null);
    this.loadCursor = null;
    this.loadCrops(false);
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

  formatRange(summary: { start_date: string; end_date: string } | null): string {
    if (!summary) {
      return '—';
    }
    return `${summary.start_date.slice(0, 10)} – ${summary.end_date.slice(0, 10)}`;
  }

  /** 横軸は chart_calendar_year（API・サーバの「今年」）の1/1〜12/31。帯の左端＝開始の目安 */
  chartTimelineContext(c: EntryScheduleCropListItem): { min: number; max: number; year: number } | null {
    if (!c.sowing_summary && !c.transplant_summary) {
      return null;
    }
    const y =
      this.listResponse()?.prediction?.chart_calendar_year ?? new Date().getFullYear();
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

  isAllIneligibleEmpty(response: EntryScheduleCropsListResponse): boolean {
    if (response.crops.length === 0) {
      return false;
    }
    return response.crops.every(
      (crop) => !crop.eligible && !crop.sowing_summary && !crop.transplant_summary,
    );
  }

}
