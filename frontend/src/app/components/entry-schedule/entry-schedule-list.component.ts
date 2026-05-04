import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
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

const ENTRY_SCHEDULE_HTTP_TIMEOUT_MS = 25_000;
const PAGE_LIMIT = 20;

@Component({
  selector: 'app-entry-schedule-list',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule, RouterLink],
  template: `
    <main class="page-main public-plans-wrapper">
      <div class="free-plans-container">
        <div class="compact-header-card">
          <h1 class="compact-header-title">
            <span class="title-icon" aria-hidden="true">📅</span>
            <span class="title-text">{{ 'entrySchedule.title' | translate }}</span>
          </h1>
        </div>

        <section class="content-card" aria-labelledby="entry-schedule-heading">
          <h2 id="entry-schedule-heading" class="section-heading">
            {{ 'entrySchedule.selectFarm' | translate }}
          </h2>
          @if (farmsLoading()) {
            <p class="muted master-loading">{{ 'entrySchedule.loading' | translate }}</p>
          } @else if (farmsError()) {
            <p class="error-message">{{ farmsError()! | translate }}</p>
            <button type="button" class="btn btn-secondary mt-2" (click)="retryFarms()">
              {{ 'entrySchedule.retry' | translate }}
            </button>
          } @else if (farms().length === 0) {
            <p class="muted">{{ 'entrySchedule.noFarms' | translate }}</p>
          } @else {
            <div class="entry-schedule-controls">
              <label class="sr-only" for="entry-farm-select">{{ 'entrySchedule.selectFarm' | translate }}</label>
              <select
                id="entry-farm-select"
                class="form-control entry-schedule-select"
                [ngModel]="selectedFarmId()"
                (ngModelChange)="onFarmChange($event)"
                [compareWith]="compareFarmId"
              >
                <option [ngValue]="null" disabled>{{ 'entrySchedule.selectFarm' | translate }}</option>
                @for (f of farms(); track f.id) {
                  <option [ngValue]="f.id">{{ f.name }}</option>
                }
              </select>
              <button
                type="button"
                class="btn btn-primary"
                [disabled]="selectedFarmId() == null || cropsLoading()"
                (click)="loadCrops(false)"
              >
                {{ 'entrySchedule.show' | translate }}
              </button>
            </div>
          }

          @if (selectedFarmId() == null && farms().length > 0 && !farmsLoading()) {
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
                    <div class="es-mini-chart muted" style="font-size: 0.85rem">{{ 'entrySchedule.viz.noWindow' | translate }}</div>
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
            @if (listResponse()!.meta.has_more) {
              <div class="mt-4">
                <button type="button" class="btn btn-secondary" [disabled]="cropsLoading()" (click)="loadCrops(true)">
                  {{ 'entrySchedule.loadMore' | translate }}
                </button>
              </div>
            }
            <p class="footer-disclaimer muted mt-4">{{ 'entrySchedule.listDisclaimer' | translate }}</p>
          }
        </section>
      </div>
    </main>
  `,
  styleUrls: ['../public-plans/public-plan.component.css', './entry-schedule-visual.css'],
  styles: [
    `
      .entry-schedule-controls {
        display: flex;
        flex-wrap: wrap;
        gap: 0.75rem;
        align-items: center;
      }
      .entry-schedule-select {
        min-width: 14rem;
        max-width: 100%;
      }
      .flow-detail-expanded {
        margin-top: 0.75rem;
        padding: 0.75rem;
        background: var(--color-surface-alt, #f8fafc);
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
      .sr-only {
        position: absolute;
        width: 1px;
        height: 1px;
        padding: 0;
        margin: -1px;
        overflow: hidden;
        clip: rect(0, 0, 0, 0);
        border: 0;
      }
      .placeholder-block {
        padding: 1.5rem;
        border: 1px dashed var(--color-border, #ccc);
        border-radius: 8px;
        text-align: center;
      }
      .meta-line {
        display: block;
      }
      .flow-summary {
        display: block;
        font-size: 0.9rem;
      }
      .btn-link {
        background: none;
        border: none;
        color: var(--color-link, #1a5fb4);
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
        }
      });
  }

  retryFarms(): void {
    this.farmsLoading.set(true);
    this.loadFarmsList();
  }

  compareFarmId(a: number | null, b: number | null): boolean {
    return a === b;
  }

  onFarmChange(id: number | null): void {
    this.selectedFarmId.set(id);
    this.listResponse.set(null);
    this.loadCursor = null;
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

}
