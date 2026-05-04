import { Component, DestroyRef, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { combineLatest } from 'rxjs';
import { ENTRY_SCHEDULE_GATEWAY } from '../../usecase/entry-schedule/entry-schedule-gateway';
import {
  EntryScheduleCropShowResponse,
  EntryScheduleDateRangeSummary,
  EntrySchedulePhaseSegment
} from '../../domain/entry-schedule/entry-schedule';
import { calendarYearJanDecBounds, MONTH_NUMBERS } from './entry-schedule-timeline.util';

@Component({
  selector: 'app-entry-schedule-detail',
  standalone: true,
  imports: [CommonModule, TranslateModule, RouterLink],
  template: `
    <main class="page-main public-plans-wrapper">
      <div class="free-plans-container">
        <div class="compact-header-card">
          <h1 class="compact-header-title">
            <span class="title-icon" aria-hidden="true">🌱</span>
            <span class="title-text">{{ 'entrySchedule.detailTitle' | translate }}</span>
          </h1>
        </div>

        <p class="mt-4">
          <a routerLink="/entry-schedule" class="link-inline">{{ 'entrySchedule.back' | translate }}</a>
        </p>

        @if (loading()) {
          <p class="muted mt-4 master-loading">{{ 'entrySchedule.loading' | translate }}</p>
        } @else if (errorKey()) {
          <p class="error-message mt-4">{{ errorKey()! | translate }}</p>
          <button type="button" class="btn btn-secondary mt-2" (click)="reload()">{{ 'entrySchedule.retry' | translate }}</button>
        } @else if (data()) {
          <section class="disclaimer-banner" role="region" aria-label="disclaimer">
            <p>{{ data()!.crop.entry_disclaimer }}</p>
          </section>

          <section class="prediction-strip es-meta-chips mt-4" role="status">
            @if (data()!.prediction.generated_at) {
              <span class="es-meta-chip"
                >{{ 'entrySchedule.predictionFresh' | translate }}: {{ data()!.prediction.generated_at!.slice(0, 16) }}</span
              >
            }
            @if (data()!.prediction.prediction_end_date) {
              <span class="es-meta-chip"
                >{{ 'entrySchedule.predictionUntil' | translate }}: {{ data()!.prediction.prediction_end_date!.slice(0, 10) }}</span
              >
            }
          </section>

          <section class="content-card mt-4" aria-labelledby="crop-name-heading">
            <h2 id="crop-name-heading" class="es-detail-hero">{{ data()!.crop.name }}</h2>
            <p class="reason-summary">{{ data()!.crop.reason_summary }}</p>
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
                  [attr.aria-label]="'entrySchedule.viz.ganttAria' | translate: { name: data()!.crop.name }"
                >
                  <div class="es-year-banner" aria-hidden="true">
                    {{ 'entrySchedule.viz.axisYear' | translate: { year: gctx.year } }}
                  </div>
                  <div class="es-gantt-row">
                    <div class="es-gantt-row-label">
                      <span class="es-dot sow" aria-hidden="true"></span>
                      {{ data()!.crop.labels.sowing }}
                    </div>
                    <div class="es-gantt-track">
                      @for (w of data()!.crop.sowing_windows; track w.start_date + w.end_date) {
                        <div
                          class="es-gantt-seg sow"
                          [attr.title]="'entrySchedule.viz.bandStartHint' | translate"
                          [ngStyle]="barSeg(w, gctx)"
                        ></div>
                      }
                      @if (data()!.crop.sowing_windows.length === 0) {
                        <span class="es-gantt-empty">{{ 'entrySchedule.viz.noWindow' | translate }}</span>
                      }
                    </div>
                  </div>
                  <div class="es-gantt-row">
                    <div class="es-gantt-row-label">
                      <span class="es-dot transplant" aria-hidden="true"></span>
                      {{ data()!.crop.labels.transplanting }}
                    </div>
                    <div class="es-gantt-track">
                      @for (w of data()!.crop.transplant_windows; track w.start_date + w.end_date) {
                        <div
                          class="es-gantt-seg transplant"
                          [attr.title]="'entrySchedule.viz.bandStartHint' | translate"
                          [ngStyle]="barSeg(w, gctx)"
                        ></div>
                      }
                      @if (data()!.crop.transplant_windows.length === 0) {
                        <span class="es-gantt-empty">{{ 'entrySchedule.viz.noWindow' | translate }}</span>
                      }
                    </div>
                  </div>
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
                <h4>{{ data()!.crop.labels.sowing }}</h4>
                <ul>
                  @for (w of data()!.crop.sowing_windows; track w.start_date + w.end_date) {
                    <li>{{ w.start_date.slice(0, 10) }} – {{ w.end_date.slice(0, 10) }}</li>
                  }
                  @if (data()!.crop.sowing_windows.length === 0) {
                    <li>—</li>
                  }
                </ul>
              </div>
              <div class="window-block">
                <h4>{{ data()!.crop.labels.transplanting }}</h4>
                <ul>
                  @for (w of data()!.crop.transplant_windows; track w.start_date + w.end_date) {
                    <li>{{ w.start_date.slice(0, 10) }} – {{ w.end_date.slice(0, 10) }}</li>
                  }
                  @if (data()!.crop.transplant_windows.length === 0) {
                    <li>—</li>
                  }
                </ul>
              </div>
            }

            @if (data()!.crop.phase_segments?.length) {
              <h3 class="subsection-title">{{ 'entrySchedule.phases' | translate }}</h3>
              <div class="es-phase-rail" role="list">
                @for (p of data()!.crop.phase_segments!; track p.phase_key) {
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

            @if (data()!.crop.rough_timeline?.length) {
              <h3 class="subsection-title">{{ 'entrySchedule.timeline' | translate }}</h3>
              <ul class="es-month-vtimeline">
                @for (t of data()!.crop.rough_timeline!; track t.month) {
                  <li>
                    <span class="es-month-chip">{{ t.month }}</span>
                    <div class="es-month-body">{{ t.summary }}</div>
                  </li>
                }
              </ul>
            }

            <section class="next-task mt-4" aria-labelledby="next-task-h">
              <h3 id="next-task-h" class="subsection-title">{{ 'entrySchedule.nextTask' | translate }}</h3>
              @if (data()!.crop.next_task; as nt) {
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
              @for (s of data()!.crop.crop_stages; track s.id) {
                <li>{{ s.order }}. {{ s.name }}</li>
              }
            </ol>
          </section>
        }
      </div>
    </main>
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
        color: var(--color-text-muted, #555);
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
        background: var(--color-surface-alt, #f5f5f5);
        border-radius: 8px;
        font-size: 0.9rem;
      }
      .reason-parts {
        white-space: pre-wrap;
        font-size: 0.85rem;
        margin: 0.5rem 0 0;
      }
      .phase-list,
      .timeline-list {
        margin-left: 1.25rem;
      }
      .empty-reason {
        color: var(--color-text-muted, #666);
      }
      .ml-2 {
        margin-left: 0.5rem;
      }
    `
  ]
})
export class EntryScheduleDetailComponent implements OnInit {
  private readonly gateway = inject(ENTRY_SCHEDULE_GATEWAY);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly destroyRef = inject(DestroyRef);

  readonly monthTicks = [...MONTH_NUMBERS];

  readonly data = signal<EntryScheduleCropShowResponse | null>(null);
  readonly loading = signal(true);
  readonly errorKey = signal<string | null>(null);

  ngOnInit(): void {
    combineLatest([this.route.paramMap, this.route.queryParamMap])
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(() => this.fetchFromRoute());
  }

  reasonPartsJson(): string {
    const parts = this.data()?.crop.reason_parts;
    if (!parts) {
      return '';
    }
    try {
      return JSON.stringify(parts, null, 2);
    } catch {
      return String(parts);
    }
  }

  detailGanttContext(): { min: number; max: number; year: number } | null {
    const crop = this.data()?.crop;
    if (!crop) {
      return null;
    }
    const hasBand =
      crop.sowing_windows.length > 0 ||
      crop.transplant_windows.length > 0 ||
      (crop.phase_segments?.some((p) => p.start_date && p.end_date) ?? false);
    if (!hasBand) {
      return null;
    }
    const y = this.data()?.prediction?.chart_calendar_year ?? new Date().getFullYear();
    return calendarYearJanDecBounds(y);
  }

  barSeg(w: EntryScheduleDateRangeSummary, ctx: { min: number; max: number }): Record<string, string> {
    const start = Date.parse(w.start_date);
    const end = Date.parse(w.end_date);
    const span = ctx.max - ctx.min;
    if (
      !Number.isFinite(start) ||
      !Number.isFinite(end) ||
      !Number.isFinite(ctx.min) ||
      !Number.isFinite(ctx.max) ||
      !Number.isFinite(span) ||
      span <= 0
    ) {
      return { display: 'none' };
    }
    const leftRaw = ((start - ctx.min) / span) * 100;
    const rightRaw = ((end - ctx.min) / span) * 100;
    const leftPct = Math.max(0, Math.min(100, leftRaw));
    const rightPct = Math.max(0, Math.min(100, rightRaw));
    const widthPct = Math.max(0.4, rightPct - leftPct);
    return {
      left: `${leftPct}%`,
      width: `${widthPct}%`
    };
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

  private fetchFromRoute(): void {
    const cropId = this.route.snapshot.paramMap.get('cropId');
    const farmIdRaw = this.route.snapshot.queryParamMap.get('farmId');
    if (!cropId || !farmIdRaw) {
      void this.router.navigate(['/entry-schedule']);
      return;
    }
    const farmId = Number.parseInt(farmIdRaw, 10);
    const cId = Number.parseInt(cropId, 10);
    if (Number.isNaN(farmId) || Number.isNaN(cId)) {
      void this.router.navigate(['/entry-schedule']);
      return;
    }
    this.loading.set(true);
    this.errorKey.set(null);
    this.data.set(null);

    this.gateway.getEntryScheduleCrop(farmId, cId).subscribe({
      next: (res) => {
        this.data.set(res);
        this.loading.set(false);
      },
      error: () => {
        this.errorKey.set('entrySchedule.error');
        this.loading.set(false);
      }
    });
  }
}
