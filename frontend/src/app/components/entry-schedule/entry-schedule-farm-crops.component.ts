import { Component, OnInit, inject, ChangeDetectorRef, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import {
  EntryScheduleFarmCropsView,
  EntryScheduleFarmCropsViewState
} from './entry-schedule-farm-crops.view';
import { LoadEntryScheduleCropsUseCase } from '../../usecase/entry-schedule/load-entry-schedule-crops.usecase';
import { ResolveEntryScheduleFarmUseCase } from '../../usecase/entry-schedule/resolve-entry-schedule-farm.usecase';
import {
  EntryScheduleFarmCropsPresenter,
  ENTRY_SCHEDULE_FARM_CROPS_PROVIDERS
} from '../../adapters/entry-schedule/entry-schedule-farm-crops.providers';
import { Farm } from '../../domain/farms/farm';
import { EntryScheduleCropListItem } from '../../domain/entry-schedule/entry-schedule';
import { detectBrowserRegion } from '../../core/browser-region';
import { FlashMessageService } from '../../services/flash-message.service';
import { FunnelShellComponent } from '../shared/shells/funnel-shell.component';
import { EntryScheduleWizardProgressComponent } from './entry-schedule-wizard-progress.component';
import { MasterContextHeaderComponent } from '../masters/master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../masters/master-context-header/master-context-crumb';
import { displayEntryScheduleFarmName } from './entry-schedule-farm-display';
import {
  MONTH_NUMBERS,
  timelineBoundsFromSummaries,
} from '../../domain/entry-schedule/entry-schedule-timeline-bounds';
import { segmentStylesForRange } from '../../domain/entry-schedule/entry-schedule-timeline-segment';

const PAGE_LIMIT = 20;

const initialControl: EntryScheduleFarmCropsViewState = {
  farmLoading: true,
  selectedFarmId: null,
  selectedFarm: null,
  listResponse: null,
  cropsLoading: false,
  cropsError: null,
  loadCursor: null
};

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
  providers: [...ENTRY_SCHEDULE_FARM_CROPS_PROVIDERS],
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
          @if (control.selectedFarm; as farm) {
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

            @if (control.farmLoading) {
              <p class="muted master-loading">{{ 'entrySchedule.loading' | translate }}</p>
            } @else if (control.cropsLoading) {
              <p class="muted mt-4 master-loading">{{ 'entrySchedule.loading' | translate }}</p>
            } @else if (control.cropsError) {
              <p class="error-message mt-4">{{ control.cropsError | translate }}</p>
              <button type="button" class="btn btn-secondary mt-2" (click)="loadCrops(false)">
                {{ 'entrySchedule.retry' | translate }}
              </button>
            } @else if (control.listResponse) {
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
                  @if (control.listResponse!.prediction.generated_at) {
                    <span class="meta-line"
                      >{{ 'entrySchedule.predictionFresh' | translate }}:
                      {{ control.listResponse!.prediction.generated_at | slice: 0 : 16 }}</span
                    >
                  }
                  @if (control.listResponse!.prediction.prediction_end_date) {
                    <span class="meta-line"
                      >{{ 'entrySchedule.predictionUntil' | translate }}:
                      {{ control.listResponse!.prediction.prediction_end_date | slice: 0 : 10 }}</span
                    >
                  }
                </div>
                <div class="es-crop-grid" role="list">
                  @for (c of control.listResponse!.crops; track c.id; let idx = $index) {
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
                            {{ 'entrySchedule.viz.axisYear' | translate: { year: ctx.yearLabel } }}
                          </div>
                          <div class="es-mini-rows">
                            @if (c.sowing_summary) {
                              <div class="es-mini-row">
                                <span class="es-mini-row-label">{{ 'entrySchedule.viz.sowBand' | translate }}</span>
                                <div class="es-track">
                                  @for (
                                    seg of segmentStylesForRange(
                                      c.sowing_summary.start_date,
                                      c.sowing_summary.end_date,
                                      ctx
                                    );
                                    track $index
                                  ) {
                                    <div
                                      class="es-seg sow"
                                      [attr.title]="'entrySchedule.viz.bandStartHint' | translate"
                                      [ngStyle]="seg"
                                    ></div>
                                  }
                                </div>
                              </div>
                            }
                            @if (c.transplant_summary) {
                              <div class="es-mini-row">
                                <span class="es-mini-row-label">{{
                                  'entrySchedule.viz.transplantBand' | translate
                                }}</span>
                                <div class="es-track">
                                  @for (
                                    seg of segmentStylesForRange(
                                      c.transplant_summary.start_date,
                                      c.transplant_summary.end_date,
                                      ctx
                                    );
                                    track $index
                                  ) {
                                    <div
                                      class="es-seg transplant"
                                      [attr.title]="'entrySchedule.viz.bandStartHint' | translate"
                                      [ngStyle]="seg"
                                    ></div>
                                  }
                                </div>
                              </div>
                            }
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
                @if (control.listResponse!.meta.has_more) {
                  <div class="mt-4">
                    <button
                      type="button"
                      class="btn btn-secondary"
                      [disabled]="control.cropsLoading"
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
export class EntryScheduleFarmCropsComponent implements EntryScheduleFarmCropsView, OnInit {
  private readonly resolveFarmUseCase = inject(ResolveEntryScheduleFarmUseCase);
  private readonly loadCropsUseCase = inject(LoadEntryScheduleCropsUseCase);
  private readonly presenter = inject(EntryScheduleFarmCropsPresenter);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly flash = inject(FlashMessageService);
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);

  readonly monthTicks = [...MONTH_NUMBERS];
  readonly segmentStylesForRange = segmentStylesForRange;
  readonly flowDetailOpen = signal<Set<number>>(new Set());

  private _control: EntryScheduleFarmCropsViewState = initialControl;
  get control(): EntryScheduleFarmCropsViewState {
    return this._control;
  }
  set control(value: EntryScheduleFarmCropsViewState) {
    this._control = value;
    this.cdr.detectChanges();
  }

  get contextCrumbs(): MasterContextCrumb[] {
    const farm = this.control.selectedFarm;
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
    this.presenter.setView(this);
    const rawFarmId = this.route.snapshot.paramMap.get('farmId');
    const farmId = rawFarmId != null ? Number(rawFarmId) : NaN;
    if (!Number.isFinite(farmId) || farmId <= 0) {
      this.redirectInvalidFarm();
      return;
    }
    this.resolveFarm(farmId);
  }

  afterFarmResolved(_farm: Farm): void {
    this.loadCrops(false);
  }

  onInvalidFarm(): void {
    this.redirectInvalidFarm();
  }

  private redirectInvalidFarm(): void {
    this.flash.show({ type: 'warning', text: 'entrySchedule.invalid_farm_id' });
    void this.router.navigate(['/entry-schedule'], { replaceUrl: true });
  }

  private resolveFarm(farmId: number): void {
    const region = detectBrowserRegion();
    this.control = {
      ...this.control,
      farmLoading: true
    };
    this.resolveFarmUseCase.execute({ region, farmId });
  }

  detailQueryParams(): Record<string, string | number> {
    const farmId = this.control.listResponse?.farm.id ?? this.control.selectedFarmId;
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
    const farmId = this.control.selectedFarmId;
    if (farmId == null) {
      return;
    }
    this.control = {
      ...this.control,
      cropsLoading: true,
      cropsError: null,
      ...(append ? {} : { listResponse: null, loadCursor: null })
    };
    this.loadCropsUseCase.execute({
      farmId,
      append,
      limit: PAGE_LIMIT,
      cursor: append ? this.control.loadCursor : undefined
    });
  }

  chartTimelineContext(c: EntryScheduleCropListItem): { min: number; max: number; yearLabel: string } | null {
    return timelineBoundsFromSummaries([c.sowing_summary, c.transplant_summary]);
  }

  formatRangeShort(summary: { start_date: string; end_date: string }): string {
    const a = summary.start_date.slice(5, 10).replace('-', '/');
    const b = summary.end_date.slice(5, 10).replace('-', '/');
    return `${a} – ${b}`;
  }

  listEmptyKind(): 'noCrops' | 'allIneligible' | null {
    const res = this.control.listResponse;
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
