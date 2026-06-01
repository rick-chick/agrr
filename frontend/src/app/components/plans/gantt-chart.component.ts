import { Component, EventEmitter, Input, OnChanges, OnInit, Output, SimpleChanges, ElementRef, ViewChild, AfterViewInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { CultivationPlanData, CultivationData, AvailableCropData } from '../../domain/plans/cultivation-plan-data';
import {
  addMonths,
  buildGanttFieldGroups,
  buildGanttTimeAxisSegments,
  clampGanttChartWidth,
  computeGanttBarLabelPosition,
  computeGanttTargetFieldIndex,
  computeGanttBarParams,
  computeGanttChartHeight,
  computeGanttVisibleRangeEnd,
  determineGanttTimeScale,
  formatGanttVisibleRangeLabel,
  formatIsoDateOnly,
  GanttFieldGroup,
  GanttTimeAxisSegment,
  GanttTimeScale,
  GanttTimeUnit,
  ganttCropFillColor,
  ganttCropStrokeColor,
  normalizePlanBounds,
  applyGanttCultivationMove,
  buildGanttAdjustMove,
  computeGanttFieldRowHighlightY,
  getGanttDragActivationThresholdPx,
  resolveGanttDragCommit,
  resolveGanttEndingTouchIndex,
  shouldActivateGanttDrag,
  shouldIgnoreGanttPointerCancel,
  shouldReinitializeGanttVisibleRange
} from '../../domain/plans/gantt-chart-layout';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { PlanService, AddCropRequest } from '../../services/plans/plan.service';
import { FlashMessageService } from '../../services/flash-message.service';

interface GanttConfig {
  margin: { top: number; right: number; bottom: number; left: number };
  rowHeight: number;
  barHeight: number;
  barPadding: number;
  width: number;
  height: number;
}

interface VisibleRange {
  startDate: Date;
  endDate: Date;
  label: string;
}

@Component({
  selector: 'app-gantt-chart',
  standalone: true,
  imports: [CommonModule, TranslateModule, FormsModule],
  template: `
    @if (showOptimizationLock) {
      <div class="screen-lock-overlay" aria-live="polite">
        <div class="screen-lock-content">
          <div class="spinner"></div>
          <p>{{ 'plans.gantt.optimizing' | translate }}</p>
        </div>
      </div>
    }
    <div class="gantt-page">
      <div class="gantt-action-bar">
        <button
          class="action-button"
          type="button"
          (click)="toggleCropPalette()"
          [class.active]="isCropPaletteOpen">
          @if (!isCropPaletteOpen) {
            <span>{{ 'js.gantt.add_crop_button' | translate }}</span>
          } @else {
            <span>{{ 'js.gantt.crop_palette_cancel' | translate }}</span>
          }
        </button>
        <button
          class="action-button"
          type="button"
          (click)="toggleFieldForm()"
          [class.active]="fieldFormVisible">
          @if (!fieldFormVisible) {
            <span>{{ 'js.gantt.add_field_button' | translate }}</span>
          } @else {
            <span>{{ 'js.gantt.crop_palette_cancel' | translate }}</span>
          }
        </button>
        <div class="gantt-range-controls">
        <button
          class="range-button"
          type="button"
          (click)="shiftVisibleRange(-1)">
            {{ 'plans.gantt.range.prev_month' | translate }}
        </button>
          <div class="gantt-range-label">
            <strong class="gantt-range-label__value">{{ visibleRangeLabel || '—' }}</strong>
          </div>
        <button
          class="range-button"
          type="button"
          (click)="shiftVisibleRange(1)">
            {{ 'plans.gantt.range.next_month' | translate }}
        </button>
        </div>
      </div>

      @if (isCropPaletteOpen) {
        <div class="crop-palette">
          <p class="section-title">{{ 'js.gantt.crop_palette_title' | translate }}</p>
          @if (data?.data?.available_crops && data!.data.available_crops!.length > 0) {
            <div class="crop-list">
              @for (crop of data!.data.available_crops!; track crop.id) {
                <button
                  class="crop-card"
                  type="button"
                  [class.selected]="selectedCrop?.id === crop.id"
                  (click)="selectCrop(crop)">
                  <span class="crop-name">{{ crop.name }}</span>
                  <span class="crop-variety">{{ crop.variety }}</span>
                </button>
              }
            </div>
          } @else {
            <p class="empty-state">{{ 'js.gantt.crop_palette_no_crops' | translate }}</p>
          }


        </div>
      }

      @if (fieldFormVisible) {
        <div class="field-form">
          <div class="field-form-row">
            <label>{{ 'js.gantt.field_form_name_label' | translate }}</label>
            <input
              type="text"
              [(ngModel)]="newFieldName"
              name="newFieldName"
              [placeholder]="'js.gantt.field_form_name_placeholder' | translate" />
          </div>
          <div class="field-form-row">
            <label>{{ 'js.gantt.field_form_area_label' | translate }}</label>
            <input
              type="number"
              [(ngModel)]="newFieldArea"
              name="newFieldArea"
              min="0"
              step="1"
              [placeholder]="'js.gantt.field_form_area_placeholder' | translate" />
          </div>
          <button
            class="action-button"
            type="button"
            (click)="confirmAddField()"
            [disabled]="isFieldFormLoading || !newFieldName || !newFieldArea">
            @if (!isFieldFormLoading) {
              <span>{{ 'js.gantt.field_form_submit' | translate }}</span>
            } @else {
              <span>{{ 'js.gantt.adding_field_loading' | translate }}</span>
            }
          </button>
        </div>
      }

      <div class="gantt-container" #container>
        @if (!data || !data.data || !data.data.fields || data.data.fields.length === 0 || !data.data.cultivations) {
          <div class="no-data-message">
            @if (!data) {
              <p>{{ 'plans.gantt.no_plan_data' | translate }}</p>
            } @else if (!data.data.fields || data.data.fields.length === 0) {
              <p>{{ 'plans.gantt.no_field_data' | translate }}</p>
            } @else {
              <p>{{ 'plans.gantt.no_data' | translate }}</p>
            }
          </div>
        } @else {
          <div class="gantt-scroll-area">
            <svg #svg class="custom-gantt-chart" [attr.width]="config.width" [attr.height]="config.height">
            <defs>
              <linearGradient id="bgGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                <stop offset="0%" style="stop-color:#ffffff;stop-opacity:1" />
                <stop offset="100%" style="stop-color:#f9fafb;stop-opacity:1" />
              </linearGradient>
            </defs>
            
            <!-- Background -->
            <rect [attr.width]="config.width" [attr.height]="config.height" fill="url(#bgGradient)" class="gantt-background" />
            
            <!-- Field Row Highlight (for drag feedback) -->
            <rect #highlightRect class="field-row-highlight" 
                  [attr.width]="config.width" 
                  fill="#FFEB3B" 
                  opacity="0" 
                  style="pointer-events: none;" />

            <!-- Timeline Header -->
            <g class="timeline-header">
              <text x="20" y="30" class="header-label" font-size="14" font-weight="bold" fill="#374151">
                {{ 'shared.navbar.farms' | translate }}
              </text>
              @for (month of months; track month.date.getTime()) {
                @if (month.showLabel) {
                  <text [attr.x]="month.x + (month.width / 2)" y="30" class="month-label" text-anchor="middle" font-size="12" font-weight="600" fill="#1F2937">
                    {{ month.label }}
                  </text>
                }
                @if (month.showYear) {
                  <text [attr.x]="month.x + (month.width / 2)" y="15" class="year-label" text-anchor="middle" font-size="11" font-weight="bold" fill="#6B7280">
                    {{ month.year }}{{ 'plans.gantt.labels.year' | translate }}
                  </text>
                }
                <line [attr.x1]="month.x" y1="40" [attr.x2]="month.x" [attr.y2]="config.height" stroke="#E5E7EB" stroke-width="1" />
              }
            </g>

            <!-- Field Rows -->
            @for (group of fieldGroups; track group.fieldId; let i = $index) {
              <g class="field-row" [attr.transform]="'translate(0, ' + (config.margin.top + i * config.rowHeight) + ')'">
                <text x="30" [attr.y]="config.rowHeight / 2 + 5" class="field-label" text-anchor="middle" font-size="14" font-weight="600" fill="#374151">
                  {{ group.fieldName }}
                </text>
                <line [attr.x1]="config.margin.left - 10" y1="0" [attr.x2]="config.margin.left - 10" [attr.y2]="config.rowHeight" stroke="#D1D5DB" stroke-width="2" />
                @if (group.cultivations.length === 0) {
                  <text
                    class="field-delete-icon"
                    [attr.x]="config.margin.left - 40"
                    [attr.y]="config.rowHeight / 2 + 5"
                    font-size="14"
                    fill="#ef4444"
                    (click)="confirmRemoveField(group); $event.stopPropagation()">
                    ×
                  </text>
                }
                
                <!-- Cultivation Bars -->
                @for (cultivation of group.cultivations; track cultivation.id) {
                  @if (getBarParams(cultivation); as params) {
                    <g class="cultivation-bar" 
                       (pointerdown)="onPointerDown($event, cultivation)"
                       [class.dragging]="draggedCultivation?.id === cultivation.id"
                       [attr.data-id]="cultivation.id"
                       [attr.data-field]="cultivation.field_name">
                      <rect [attr.x]="params.x" 
                            [attr.y]="config.barPadding" 
                            [attr.width]="params.width" 
                            [attr.height]="config.barHeight" 
                            rx="6" ry="6"
                            [attr.fill]="getCropColor(cultivation.crop_name)"
                            [attr.stroke]="getCropStrokeColor(cultivation.crop_name)"
                            stroke-width="2.5"
                            class="bar-bg"
                            style="cursor: grab;" />
                      <text
                            [attr.x]="params.width > 72 ? params.x + (params.width - 32) / 2 : params.x + 10"
                            [attr.y]="config.barPadding + config.barHeight / 2 + 5"
                            class="bar-label"
                            [attr.text-anchor]="params.width > 72 ? 'middle' : 'start'"
                            font-size="12"
                            font-weight="600"
                            fill="#1F2937"
                            style="pointer-events: none;">
                        {{ cultivation.crop_name }}
                      </text>
                      @if (!isMobileLayout) {
                        <g
                          class="cultivation-delete-control"
                          (click)="confirmRemoveCultivation(cultivation); $event.stopPropagation()">
                          <circle
                            [attr.cx]="params.x + params.width - 14"
                            [attr.cy]="config.barPadding + config.barHeight / 2"
                            r="9"
                            fill="white"
                            stroke="#ef4444"
                            stroke-width="2" />
                          <text
                            [attr.x]="params.x + params.width - 14"
                            [attr.y]="config.barPadding + config.barHeight / 2 + 4"
                            font-size="12"
                            text-anchor="middle"
                            fill="#ef4444">
                            ×
                          </text>
                        </g>
                      }
                    </g>
                  }
                }
              </g>
            }
            </svg>
          </div>
        }
      </div>

      @if (showTrashDropzone) {
        <div
          #trashDropzone
          class="gantt-trash-dropzone"
          [class.gantt-trash-dropzone--active]="trashDropzoneActive"
          [attr.aria-label]="'plans.gantt.trash_drop_label' | translate"
          role="button"
        >
          <svg class="gantt-trash-dropzone__icon" viewBox="0 0 24 24" aria-hidden="true">
            <path
              fill="currentColor"
              d="M9 3h6l1 2h4v2H4V5h4l1-2zm1 6h2v9h-2V9zm4 0h2v9h-2V9zM7 9h2v9H7V9zm-1 11h12a2 2 0 0 0 2-2V9H6v9a2 2 0 0 0 2 2z" />
          </svg>
        </div>
      }
    </div>
  `,
  styleUrls: ['./gantt-chart.component.css']
})
export class GanttChartComponent implements OnInit, OnChanges, AfterViewInit, OnDestroy {
  @Input() data: CultivationPlanData | null = null;
  @Input() planType: 'public' | 'private' = 'private';
  @Output() cultivationSelected = new EventEmitter<{
    cultivationId: number;
    planType: 'public' | 'private';
  }>();
  @Output() visibleRangeChange = new EventEmitter<VisibleRange>();

  @ViewChild('container') container!: ElementRef<HTMLDivElement>;
  @ViewChild('svg') svgElement!: ElementRef<SVGSVGElement>;
  @ViewChild('highlightRect') highlightRect!: ElementRef<SVGRectElement>;
  @ViewChild('trashDropzone') trashDropzone?: ElementRef<HTMLElement>;

  /** max-width: 768px — matches project mobile breakpoints */
  isMobileLayout = false;
  showTrashDropzone = false;
  trashDropzoneActive = false;

  config: GanttConfig = {
    margin: { top: 60, right: 20, bottom: 12, left: 80 },
    rowHeight: 68,
    barHeight: 48,
    barPadding: 8,
    width: 1200,
    height: 500
  };

  fieldGroups: GanttFieldGroup[] = [];
  months: GanttTimeAxisSegment[] = [];
  timeScale: GanttTimeScale = { unit: GanttTimeUnit.Month, interval: 1 };
  isCropPaletteOpen = false;
  selectedCrop: AvailableCropData | null = null;
  cropStartDate: string | null = null;
  isAddCropLoading = false;

  fieldFormVisible = false;
  newFieldName = '';
  newFieldArea: number | null = null;
  isFieldFormLoading = false;

  visibleStartDate: Date | null = null;
  visibleEndDate: Date | null = null;
  visibleRangeLabel = '';
  canShiftRangeBackward = false;
  canShiftRangeForward = false;

  private lastPlanStartTime = 0;
  private lastPlanEndTime = 0;
  
  private isDragging = false;
  draggedCultivation: CultivationData | null = null;
  private dragStartX = 0;
  private dragStartY = 0;
  private pointerDragDistance = 0;
  private activePointerId: number | null = null;
  private mobileMediaQuery: MediaQueryList | null = null;
  private readonly onMobileLayoutChange = () => {
    this.isMobileLayout = this.mobileMediaQuery?.matches ?? false;
    if (!this.isMobileLayout) {
      this.clearTrashDropzoneUi();
    }
    this.scheduleDetectChanges();
  };
  private originalBarX = 0;
  private originalBarY = 0;
  private dragStartDisplayStartDate: Date | null = null;
  private dragStartDisplayEndDate: Date | null = null;
  private originalFieldIndex = -1;
  private cachedBarBg: SVGRectElement | null = null;
  private cachedLabel: SVGTextElement | null = null;
  private barWidth = 0;
  private barHeight = 0;
  private initialMouseSvgOffset = { x: 0, y: 0 };
  private lastTargetFieldIndex = -1;
  private globalPointerMoveHandler: ((event: PointerEvent) => void) | null = null;
  private globalPointerUpHandler: ((event: PointerEvent) => void) | null = null;
  private globalPointerCancelHandler: ((event: PointerEvent) => void) | null = null;
  private globalTouchEndHandler: ((event: TouchEvent) => void) | null = null;
  private dragPointerEnded = false;
  private needsUpdate = false; // データ変更とコンテナ準備のタイミングを分離するためのフラグ
  private isDestroyed = false;
  private pendingDetectChanges = false;
  /** ドロップ後の最適化API完了までオーバーレイを表示する */
  showOptimizationLock = false;
  private planService = inject(PlanService);
  private cdr = inject(ChangeDetectorRef);
  private flashMessageService = inject(FlashMessageService);

  constructor(private translate: TranslateService) {}

  ngOnInit(): void {
    // コンテナ要素がまだ利用できないため、updateChart()は呼ばずにフラグを設定
    if (this.data) {
      this.needsUpdate = true;
    }
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['data'] && this.data) {
      // コンテナ要素が利用可能な場合のみupdateChart()を実行、そうでない場合はフラグを設定
      if (this.container?.nativeElement) {
        this.updateChart();
        this.needsUpdate = false;
        // データ変更後に画面更新を強制
        this.scheduleDetectChanges();
      } else {
        this.needsUpdate = true;
      }
    }
  }

  ngAfterViewInit(): void {
    setTimeout(() => {
      this.updateDimensions();
      if (this.needsUpdate) {
        this.updateChart();
        this.needsUpdate = false;
      }
      this.scheduleDetectChanges();
    }, 0);
    window.addEventListener('resize', this.onResize);
    if (typeof window.matchMedia === 'function') {
      this.mobileMediaQuery = window.matchMedia('(max-width: 768px)');
      this.isMobileLayout = this.mobileMediaQuery.matches;
      this.mobileMediaQuery.addEventListener('change', this.onMobileLayoutChange);
    }
  }

  ngOnDestroy(): void {
    window.removeEventListener('resize', this.onResize);
    this.mobileMediaQuery?.removeEventListener('change', this.onMobileLayoutChange);
    this.removeGlobalListeners();
    this.isDestroyed = true;
  }

  private onResize = () => {
    this.updateDimensions();
  };

  private scheduleDetectChanges() {
    if (this.pendingDetectChanges || this.isDestroyed) return;
    this.pendingDetectChanges = true;
    Promise.resolve().then(() => {
      this.pendingDetectChanges = false;
      if (!this.isDestroyed) {
        this.cdr.detectChanges();
      }
    });
  }

  private updateDimensions() {
    if (this.container) {
      const width = this.container.nativeElement.getBoundingClientRect().width;
      // 横スクロールなしにするため、コンテナ幅に合わせて調整
      // 最小幅を400pxに設定（非常に狭い画面でも動作するように）
      this.config.width = clampGanttChartWidth(width);
      if (this.data) {
        this.updateChart();
      }
    }
  }

  private ganttLabelSuffixes() {
    return {
      day: this.translate.instant('plans.gantt.labels.day'),
      month: this.translate.instant('plans.gantt.labels.month'),
      quarter: this.translate.instant('plans.gantt.labels.quarter')
    };
  }

  private updateChart() {
    if (!this.data) {
      return;
    }

    if (this.container?.nativeElement) {
      const width = this.container.nativeElement.getBoundingClientRect().width;
      if (width > 0) {
        this.config.width = clampGanttChartWidth(width);
      }
    }

    this.fieldGroups = buildGanttFieldGroups(this.data.data.fields, this.data.data.cultivations);

    this.config.height = computeGanttChartHeight({
      marginTop: this.config.margin.top,
      rowCount: this.fieldGroups.length,
      rowHeight: this.config.rowHeight,
      marginBottom: this.config.margin.bottom
    });

    const planStartRaw = new Date(this.data.data.planning_start_date);
    const planEndRaw = new Date(this.data.data.planning_end_date);
    const { start: planStart, end: planEnd } = normalizePlanBounds(planStartRaw, planEndRaw);

    const chartWidth = this.config.width - this.config.margin.left - this.config.margin.right;
    this.syncVisibleRange(planStart, planEnd);
    this.recalculateAxis(chartWidth);

    // SVG上でドラッグ中に直接変更された属性をクリアして
    // Angularの再描画で正しい縦位置（グループ位置）が反映されるようにする
    // （特にサーバー応答後に古い inline 属性が残ると縦位置が更新されないため）
    this.sanitizeSvgBars();

    // データ更新後に画面更新を強制
    this.scheduleDetectChanges();
  }

  /**
   * 直接DOM操作で書き換えられたバーの属性をリセットして
   * テンプレートのバインディング値（config.barPadding 等）が反映されるようにする
   */
  private sanitizeSvgBars() {
    const svg = this.svgElement?.nativeElement;
    if (!svg) return;

    try {
      const rects = svg.querySelectorAll('rect.bar-bg');
      rects.forEach((el: Element) => {
        const r = el as SVGRectElement;
        // Yはグループの transform と組み合わせて決まるため、
        // 各rectは常に config.barPadding を使うようにリセットする
        r.setAttribute('y', this.config.barPadding.toString());
        // ドラッグ時に保存した data-original-y は不要なので削除
        if (r.hasAttribute('data-original-y')) r.removeAttribute('data-original-y');
      });

      const labels = svg.querySelectorAll('text.bar-label');
      labels.forEach((el: Element) => {
        const t = el as SVGTextElement;
        const parent = t.parentElement;
        if (!parent) return;
        const rect = parent.querySelector('rect.bar-bg') as SVGRectElement | null;
        if (!rect) return;
        const x = parseFloat(rect.getAttribute('x') || '0');
        const width = parseFloat(rect.getAttribute('width') || '0');
        const reserve = 24;
        const y = parseFloat(rect.getAttribute('y') || this.config.barPadding.toString());
        const height = parseFloat(rect.getAttribute('height') || this.config.barHeight.toString());
        const { x: labelX, y: labelY } = computeGanttBarLabelPosition({
          barX: x,
          barWidth: width,
          labelReserve: reserve,
          barY: y,
          barHeight: height
        });
        t.setAttribute('x', labelX.toString());
        t.setAttribute('y', labelY.toString());
      });
    } catch (e) {
      // 万が一SVG操作で例外が出ても描画は継続する
      console.error('sanitizeSvgBars error', e);
    }
  }

  shiftVisibleRange(months: number) {
    if (!this.data || !this.visibleStartDate || !this.visibleEndDate) return;

    const nextStart = addMonths(this.visibleStartDate, months);
    this.setVisibleRangeFromStart(nextStart);
    this.recalculateAxis();
    this.scheduleDetectChanges();
  }

  private recalculateAxis(chartWidth?: number) {
    if (!this.visibleStartDate || !this.visibleEndDate) return;
    const width =
      chartWidth ?? this.config.width - this.config.margin.left - this.config.margin.right;
    this.timeScale = determineGanttTimeScale(this.visibleStartDate, this.visibleEndDate, width);
    this.months = buildGanttTimeAxisSegments({
      visibleStart: this.visibleStartDate,
      visibleEnd: this.visibleEndDate,
      marginLeft: this.config.margin.left,
      chartWidth: width,
      timeScale: this.timeScale,
      labelSuffixes: this.ganttLabelSuffixes()
    });
  }

  private syncVisibleRange(planStart: Date, planEnd: Date) {
    const planStartTime = planStart.getTime();
    const planEndTime = planEnd.getTime();

    if (
      shouldReinitializeGanttVisibleRange({
        planStartTime,
        planEndTime,
        lastPlanStartTime: this.lastPlanStartTime,
        lastPlanEndTime: this.lastPlanEndTime,
        visibleStart: this.visibleStartDate,
        visibleEnd: this.visibleEndDate
      })
    ) {
      this.initializeVisibleRange(planStart, planEnd);
      return;
    }

    if (this.lastPlanStartTime !== planStartTime || this.lastPlanEndTime !== planEndTime) {
      this.lastPlanStartTime = planStartTime;
      this.lastPlanEndTime = planEndTime;
    }
  }

  private initializeVisibleRange(planStart: Date, planEnd: Date) {
    this.lastPlanStartTime = planStart.getTime();
    this.lastPlanEndTime = planEnd.getTime();
    this.setVisibleRangeFromStart(planStart);
  }

  private setVisibleRangeFromStart(candidateStart: Date) {
    const start = new Date(candidateStart);
    if (isNaN(start.getTime())) {
      return;
    }
    this.visibleStartDate = start;
    this.visibleEndDate = computeGanttVisibleRangeEnd(start);
    this.updateRangeLabel();
    this.updateNavigationStates();
    this.emitVisibleRange();
  }

  private updateRangeLabel() {
    if (!this.visibleStartDate || !this.visibleEndDate) {
      this.visibleRangeLabel = '';
      return;
    }
    this.visibleRangeLabel = formatGanttVisibleRangeLabel(
      this.visibleStartDate,
      this.visibleEndDate
    );
  }

  private emitVisibleRange() {
    if (!this.visibleStartDate || !this.visibleEndDate) return;
    this.visibleRangeChange.emit({
      startDate: new Date(this.visibleStartDate),
      endDate: new Date(this.visibleEndDate),
      label: this.visibleRangeLabel
    });
  }

  private updateNavigationStates() {
    const hasRange = !!this.visibleStartDate && !!this.visibleEndDate;
    this.canShiftRangeBackward = hasRange;
    this.canShiftRangeForward = hasRange;
  }

  getBarParams(cultivation: CultivationData) {
    if (!this.data) return null;
    const planStartRaw = new Date(this.data.data.planning_start_date);
    const planEndRaw = new Date(this.data.data.planning_end_date);
    const { start: planStart, end: planEnd } = normalizePlanBounds(planStartRaw, planEndRaw);
    const visibleStart = this.visibleStartDate ?? planStart;
    const visibleEnd = this.visibleEndDate ?? planEnd;
    const chartWidth = this.config.width - this.config.margin.left - this.config.margin.right;

    return computeGanttBarParams({
      cultivationStart: new Date(cultivation.start_date),
      cultivationEnd: new Date(cultivation.completion_date),
      visibleStart,
      visibleEnd,
      marginLeft: this.config.margin.left,
      chartWidth
    });
  }

  getCropColor(name: string): string {
    return ganttCropFillColor(name ?? '');
  }

  getCropStrokeColor(name: string): string {
    return ganttCropStrokeColor(name ?? '');
  }

  onPointerDown(event: PointerEvent, cultivation: CultivationData) {
    if (event.button !== 0) return;
    // Block browser pan/scroll on the bar so horizontal drag is not stolen (especially on mobile).
    event.preventDefault();

    const target = event.currentTarget as Element | null;
    if (target?.setPointerCapture) {
      try {
        target.setPointerCapture(event.pointerId);
      } catch {
        // ignore capture failures on unsupported targets
      }
    }
    this.activePointerId = event.pointerId;
    this.dragPointerEnded = false;

    // ドラッグの準備（まだドラッグは開始していない）
    this.isDragging = false;
    this.pointerDragDistance = 0;
    this.resetTrashDropzoneState();
    this.draggedCultivation = cultivation;
    this.dragStartX = event.clientX;
    this.dragStartY = event.clientY;

    // バーの元の位置を保存（実際のSVG要素から取得）
    const barGroup = this.getBarGroupElement(cultivation.id);
    if (barGroup) {
      const barBg = barGroup.querySelector('.bar-bg') as SVGRectElement;
      if (barBg) {
        this.originalBarX = parseFloat(barBg.getAttribute('x') || '0');
        const originalBarY = parseFloat(barBg.getAttribute('y') || '0');
        // data-original-y属性として保存（Rails実装に合わせる）
        barBg.setAttribute('data-original-y', originalBarY.toString());
        this.originalBarY = originalBarY;
      }
    }

    // ドラッグ開始時の表示範囲を保存（ドラッグ中の再描画対策）
    if (this.data) {
      const { start: planStart, end: planEnd } = normalizePlanBounds(
        new Date(this.data.data.planning_start_date),
        new Date(this.data.data.planning_end_date)
      );
      this.dragStartDisplayStartDate = this.visibleStartDate ?? planStart;
      this.dragStartDisplayEndDate = this.visibleEndDate ?? planEnd;
    }

    // 現在のフィールドインデックスを保存
    this.originalFieldIndex = this.fieldGroups.findIndex(g => g.fieldName === cultivation.field_name);
    this.lastTargetFieldIndex = -1;

    this.globalPointerMoveHandler = (e: PointerEvent) => this.onPointerMove(e);
    this.globalPointerUpHandler = (e: PointerEvent) => this.onPointerUp(e);
    this.globalPointerCancelHandler = (e: PointerEvent) => this.onPointerCancel(e);

    document.addEventListener('pointermove', this.globalPointerMoveHandler);
    document.addEventListener('pointerup', this.globalPointerUpHandler);
    document.addEventListener('pointercancel', this.globalPointerCancelHandler);
    if (this.isMobileLayout) {
      this.globalTouchEndHandler = (e: TouchEvent) => this.onTouchEnd(e);
      document.addEventListener('touchend', this.globalTouchEndHandler);
    }
  }

  private onPointerMove(event: PointerEvent) {
    if (!this.draggedCultivation) return;
    if (this.activePointerId !== null && event.pointerId !== this.activePointerId) return;

    if (this.isDragging && this.isMobileLayout) {
      event.preventDefault();
    }

    const mouseDeltaX = event.clientX - this.dragStartX;
    const mouseDeltaY = event.clientY - this.dragStartY;

    const distance = Math.sqrt(mouseDeltaX * mouseDeltaX + mouseDeltaY * mouseDeltaY);
    this.pointerDragDistance = distance;
    this.updateTrashDropzoneUi(event.clientX, event.clientY);

    // ドラッグ開始判定（まだ開始していない場合）
    if (!this.isDragging) {
      if (shouldActivateGanttDrag(distance, this.isMobileLayout)) {
        if (this.isMobileLayout) {
          event.preventDefault();
        }
        // ドラッグ開始
        this.isDragging = true;

        // 要素の参照をキャッシュ
        const barGroup = this.getBarGroupElement(this.draggedCultivation.id);
        if (barGroup) {
          barGroup.classList.add('dragging');
          this.cachedBarBg = barGroup.querySelector('.bar-bg') as SVGRectElement;
          this.cachedLabel = barGroup.querySelector('.bar-label') as SVGTextElement;

          if (this.cachedBarBg) {
            this.cachedBarBg.style.cursor = 'grabbing';
            this.cachedBarBg.setAttribute('opacity', '0.8');
            this.cachedBarBg.setAttribute('stroke-width', '4');
            this.cachedBarBg.setAttribute('stroke-dasharray', '5,5');

            // サイズを取得
            this.barWidth = parseFloat(this.cachedBarBg.getAttribute('width') || '0');
            this.barHeight = parseFloat(this.cachedBarBg.getAttribute('height') || '0');

            // マウスダウン位置をSVG座標に変換
            const startSvgCoords = this.screenToSVGCoords(this.dragStartX, this.dragStartY);
            // 要素の左上とマウス位置のオフセットを記録（SVG座標系で）
            // Rails実装に合わせて、実際のY座標を使用
            const currentBarY = parseFloat(this.cachedBarBg.getAttribute('y') || '0');
            this.initialMouseSvgOffset.x = startSvgCoords.x - this.originalBarX;
            this.initialMouseSvgOffset.y = startSvgCoords.y - currentBarY;
          }
        }
      } else {
        // まだ閾値に達していない
        return;
      }
    }

    // 現在のマウス位置をSVG座標に変換
    const currentSvgCoords = this.screenToSVGCoords(event.clientX, event.clientY);

    // マウスの下にバーの角（ドラッグ開始位置）が来るように位置を計算
    const newX = currentSvgCoords.x - this.initialMouseSvgOffset.x;
    const newY = currentSvgCoords.y - this.initialMouseSvgOffset.y;

    // Y方向の移動から移動先の圃場インデックスを計算
    // Rails実装に合わせて、data-original-y属性から取得
    const ROW_HEIGHT = this.config.rowHeight;
    const originalBarY = this.cachedBarBg 
      ? parseFloat(this.cachedBarBg.getAttribute('data-original-y') || '0')
      : this.originalBarY;
    const deltaY = newY - originalBarY;
    const targetFieldIndex = computeGanttTargetFieldIndex({
      originalFieldIndex: this.originalFieldIndex,
      deltaY: deltaY,
      rowHeight: ROW_HEIGHT,
      fieldCount: this.fieldGroups.length
    });

    // ハイライトの更新（圃場が変わった場合のみ）
    if (targetFieldIndex !== this.lastTargetFieldIndex && this.highlightRect) {
      const highlightY = computeGanttFieldRowHighlightY({
        targetFieldIndex,
        rowHeight: ROW_HEIGHT,
        headerHeight: this.config.margin.top
      });

      // 圃場が変わる場合のみハイライト表示
      if (targetFieldIndex !== this.originalFieldIndex) {
        this.highlightRect.nativeElement.setAttribute('y', highlightY.toString());
        this.highlightRect.nativeElement.setAttribute('height', ROW_HEIGHT.toString());
        this.highlightRect.nativeElement.setAttribute('opacity', '0.4');
      } else {
        // 元の圃場に戻った場合はハイライトを非表示
        this.highlightRect.nativeElement.setAttribute('opacity', '0');
      }

      this.lastTargetFieldIndex = targetFieldIndex;
    }

    // SVG属性を直接更新
    if (this.cachedBarBg) {
      this.cachedBarBg.setAttribute('x', newX.toString());
      this.cachedBarBg.setAttribute('y', newY.toString());

      // ラベルも更新
      if (this.cachedLabel) {
        this.cachedLabel.setAttribute('x', (newX + (this.barWidth / 2)).toString());
        this.cachedLabel.setAttribute('y', (newY + (this.barHeight / 2) + 5).toString());
      }
    }
  }

  /**
   * デスクトップではジェスチャ中断時に commit せず元へ戻す。
   * モバイル touch では scroll 競合の偽 cancel が多く、指を離す前に走ると adjust が誤発火するため無視する
   * （commit は pointerup / touchEnd のみ）。
   */
  private onPointerCancel(event: PointerEvent) {
    if (!this.draggedCultivation) return;
    if (this.activePointerId !== null && event.pointerId !== this.activePointerId) return;
    if (shouldIgnoreGanttPointerCancel(this.isMobileLayout)) {
      return;
    }

    this.releaseActivePointerCapture(event);
    this.activePointerId = null;

    if (this.highlightRect) {
      this.highlightRect.nativeElement.setAttribute('opacity', '0');
    }

    this.restoreDraggedBarSvgToOriginal();
    this.resetVisualState();
    this.isDragging = false;
    this.draggedCultivation = null;
    this.dragStartDisplayStartDate = null;
    this.dragStartDisplayEndDate = null;
    this.clearTrashDropzoneUi();
    this.removeGlobalListeners();
  }

  /** touch 経路で pointercancel 後に pointerup が来ない場合の commit フォールバック */
  private onTouchEnd(event: TouchEvent) {
    if (!this.isMobileLayout || !this.draggedCultivation || this.dragPointerEnded) return;

    const changedTouchIds: number[] = [];
    for (let i = 0; i < event.changedTouches.length; i++) {
      const touch = event.changedTouches.item(i);
      if (touch) changedTouchIds.push(touch.identifier);
    }
    const touchIndex = resolveGanttEndingTouchIndex({
      changedTouchIds,
      activePointerId: this.activePointerId
    });
    if (touchIndex === null) return;

    const touch = event.changedTouches.item(touchIndex);
    if (!touch) return;

    this.dragPointerEnded = true;
    this.activePointerId = null;
    this.finishPointerDrag(touch.clientX, touch.clientY);
  }

  private onPointerUp(event: PointerEvent) {
    if (!this.draggedCultivation) return;
    if (this.activePointerId !== null && event.pointerId !== this.activePointerId) return;
    if (this.dragPointerEnded) return;

    this.dragPointerEnded = true;
    this.releaseActivePointerCapture(event);
    this.activePointerId = null;
    this.finishPointerDrag(event.clientX, event.clientY);
  }

  private finishPointerDrag(clientX: number, clientY: number) {
    if (!this.draggedCultivation) return;

    // ハイライトを非表示
    if (this.highlightRect) {
      this.highlightRect.nativeElement.setAttribute('opacity', '0');
    }

    if (
      this.isMobileLayout &&
      this.isDragging &&
      this.isPointerOverTrash(clientX, clientY)
    ) {
      const cultivationToRemove = this.draggedCultivation;
      this.resetVisualState();
      this.isDragging = false;
      this.draggedCultivation = null;
      this.dragStartDisplayStartDate = null;
      this.dragStartDisplayEndDate = null;
      this.clearTrashDropzoneUi();
      this.removeGlobalListeners();
      this.confirmRemoveCultivation(cultivationToRemove);
      return;
    }

    const cultivationId = this.draggedCultivation.id;
    const originalFieldName = this.draggedCultivation.field_name;
    const displayRange = this.getEffectiveDisplayRange();
    const chartWidth =
      this.config.width - this.config.margin.left - this.config.margin.right;
    const layout = {
      marginLeft: this.config.margin.left,
      chartWidth,
      rowHeight: this.config.rowHeight,
      displayStart: displayRange.start,
      displayEnd: displayRange.end
    };

    const barX = this.cachedBarBg
      ? parseFloat(this.cachedBarBg.getAttribute('x') || '0')
      : this.originalBarX;
    const barY = this.cachedBarBg
      ? parseFloat(this.cachedBarBg.getAttribute('y') || '0')
      : this.originalBarY;
    const originalBarY = this.cachedBarBg
      ? parseFloat(this.cachedBarBg.getAttribute('data-original-y') || '0')
      : this.originalBarY;

    const commit = resolveGanttDragCommit({
      barX,
      barY,
      originalBarY,
      originalBarX: this.originalBarX,
      originalFieldIndex: this.originalFieldIndex,
      originalFieldName,
      fieldGroups: this.fieldGroups,
      layout
    });

    if (this.isDragging) {
      if (commit.shouldCommit && this.data) {
        this.applyMovesLocally(
          cultivationId,
          commit.newFieldName,
          commit.newFieldIndex,
          commit.newStartDate
        );

        // ドロップ後、最適化完了までスクリーンロックを表示
        this.showOptimizationLock = true;
        this.scheduleDetectChanges();
        // API呼び出し
        this.adjustCultivation(
          cultivationId,
          commit.newFieldName,
          commit.newFieldIndex,
          commit.newStartDate
        );
      } else {
        this.resetBarPosition();
      }
    } else {
      this.resetBarPosition();
    }

    if (!this.isDragging && this.draggedCultivation) {
      this.cultivationSelected.emit({
        cultivationId: this.draggedCultivation.id,
        planType: this.planType
      });
    }

    // ドラッグ終了時のビジュアルリセット
    this.resetVisualState();

    // 状態をクリア
    this.isDragging = false;
    this.draggedCultivation = null;
    this.dragStartDisplayStartDate = null;
    this.dragStartDisplayEndDate = null;
    this.clearTrashDropzoneUi();
    this.removeGlobalListeners();
  }

  private removeGlobalListeners() {
    if (this.globalPointerMoveHandler) {
      document.removeEventListener('pointermove', this.globalPointerMoveHandler);
      this.globalPointerMoveHandler = null;
    }
    if (this.globalPointerUpHandler) {
      document.removeEventListener('pointerup', this.globalPointerUpHandler);
      this.globalPointerUpHandler = null;
    }
    if (this.globalPointerCancelHandler) {
      document.removeEventListener('pointercancel', this.globalPointerCancelHandler);
      this.globalPointerCancelHandler = null;
    }
    if (this.globalTouchEndHandler) {
      document.removeEventListener('touchend', this.globalTouchEndHandler);
      this.globalTouchEndHandler = null;
    }
  }

  private releaseActivePointerCapture(event: PointerEvent): void {
    const target = event.target as Element | null;
    if (target?.releasePointerCapture) {
      try {
        if (target.hasPointerCapture?.(event.pointerId)) {
          target.releasePointerCapture(event.pointerId);
        }
      } catch {
        // ignore
      }
    }
  }

  private restoreDraggedBarSvgToOriginal(): void {
    if (!this.cachedBarBg?.setAttribute) return;
    const originalBarY = parseFloat(
      this.cachedBarBg.getAttribute('data-original-y') || String(this.originalBarY),
    );
    this.cachedBarBg.setAttribute('x', this.originalBarX.toString());
    this.cachedBarBg.setAttribute('y', originalBarY.toString());
    if (this.cachedLabel?.setAttribute) {
      this.cachedLabel.setAttribute('x', (this.originalBarX + this.barWidth / 2).toString());
      this.cachedLabel.setAttribute('y', (originalBarY + this.barHeight / 2 + 5).toString());
    }
  }

  private updateTrashDropzoneUi(clientX: number, clientY: number) {
    if (!this.isMobileLayout || !this.draggedCultivation) {
      this.clearTrashDropzoneUi();
      return;
    }
    const shouldShow =
      this.pointerDragDistance > getGanttDragActivationThresholdPx(this.isMobileLayout) ||
      this.isDragging;
    if (this.showTrashDropzone !== shouldShow) {
      this.showTrashDropzone = shouldShow;
      this.scheduleDetectChanges();
    }
    const overTrash = shouldShow && this.isPointerOverTrash(clientX, clientY);
    if (this.trashDropzoneActive !== overTrash) {
      this.trashDropzoneActive = overTrash;
      this.scheduleDetectChanges();
    }
  }

  private resetTrashDropzoneState(): void {
    this.showTrashDropzone = false;
    this.trashDropzoneActive = false;
  }

  private clearTrashDropzoneUi() {
    if (!this.showTrashDropzone && !this.trashDropzoneActive) return;
    this.resetTrashDropzoneState();
    this.scheduleDetectChanges();
  }

  private isPointerOverTrash(clientX: number, clientY: number): boolean {
    const el = this.trashDropzone?.nativeElement;
    if (!el) return false;
    const rect = el.getBoundingClientRect();
    return (
      clientX >= rect.left &&
      clientX <= rect.right &&
      clientY >= rect.top &&
      clientY <= rect.bottom
    );
  }

  private screenToSVGCoords(screenX: number, screenY: number): { x: number; y: number } {
    if (!this.svgElement?.nativeElement) {
      console.warn('SVG element is null, returning screen coordinates');
      return { x: screenX, y: screenY };
    }

    const svg = this.svgElement.nativeElement;
    const pt = svg.createSVGPoint();
    pt.x = screenX;
    pt.y = screenY;
    const ctm = svg.getScreenCTM();
    if (ctm) {
      return pt.matrixTransform(ctm.inverse());
    }
    return { x: screenX, y: screenY };
  }

  private getBarGroupElement(cultivationId: number): SVGGElement | null {
    const svg = this.svgElement?.nativeElement;
    if (!svg) return null;
    return svg.querySelector(`g.cultivation-bar[data-id="${cultivationId}"]`) as SVGGElement;
  }

  private resetBarPosition() {
    if (!this.data) return;

    // エラー時はサーバーから最新データを再取得してロールバック
    const planId = this.data.data.id;
    const isPublicPlan = this.planType === 'public';

    if (isPublicPlan) {
      this.planService.getPublicPlanData(planId).subscribe(data => {
        if (data) {
          this.data = data;
          this.updateChart();
        }
      });
    } else {
      this.planService.getPlanData(planId).subscribe(data => {
        if (data) {
          this.data = data;
          this.updateChart();
        }
      });
    }
  }

  private handleAdjustmentFailure(message?: string) {
    this.flashMessageService.show({
      type: 'error',
      text: message ?? this.translate.instant('plans.gantt.adjust_failed')
    });
    this.showOptimizationLock = false;
    this.scheduleDetectChanges();
    this.resetBarPosition();
  }

  private extractHttpErrorMessage(error: HttpErrorResponse): string | undefined {
    if (error?.error?.message) {
      return String(error.error.message);
    }
    return error.message;
  }

  private resetVisualState() {
    const barGroup = this.draggedCultivation 
      ? this.getBarGroupElement(this.draggedCultivation.id)
      : null;

    if (barGroup) {
      barGroup.classList.remove('dragging');
    }

    if (this.cachedBarBg) {
      this.cachedBarBg.style.cursor = 'grab';
      this.cachedBarBg.setAttribute('opacity', '0.95');
      this.cachedBarBg.setAttribute('stroke-width', '2.5');
      this.cachedBarBg.removeAttribute('stroke-dasharray');
    }

    // キャッシュをクリア
    this.cachedBarBg = null;
    this.cachedLabel = null;
    this.lastTargetFieldIndex = -1;
  }

  private getEffectiveDisplayRange(): { start: Date; end: Date } {
    const { start: planStart, end: planEnd } = this.getPlanBoundsFromData();
    return {
      start:
        this.dragStartDisplayStartDate ??
        this.visibleStartDate ??
        planStart ??
        new Date(),
      end:
        this.dragStartDisplayEndDate ??
        this.visibleEndDate ??
        planEnd ??
        new Date()
    };
  }

  private applyMovesLocally(cultivationId: number, newFieldName: string, newFieldIndex: number, newStartDate: Date) {
    if (!this.data) return;

    const cultivation = this.data.data.cultivations.find(c => c.id === cultivationId);
    if (!cultivation) return;

    applyGanttCultivationMove({
      cultivation,
      fieldGroups: this.fieldGroups,
      newFieldName,
      newFieldIndex,
      newStartDate
    });
    this.updateChart();
  }

  private adjustCultivation(cultivationId: number, newFieldName: string, newFieldIndex: number, newStartDate: Date) {
    if (!this.data) return;

    const planId = this.data.data.id;
    const targetField = this.fieldGroups[newFieldIndex];
    if (!targetField) return;

    const isPublicPlan = this.planType === 'public';
    const endpoint = this.planService.buildCultivationPlanEndpoint(this.planType, planId, 'adjust');
    if (!endpoint) return;

    const moves = [buildGanttAdjustMove(cultivationId, targetField.fieldId, newStartDate)];

    this.planService.adjustPlan(endpoint, { moves }).subscribe({
      next: (response) => {
        if (response.success) {
          const clearLockAndUpdate = () => {
            this.showOptimizationLock = false;
            this.scheduleDetectChanges();
          };
          if (isPublicPlan) {
            this.planService.getPublicPlanData(planId).subscribe({
              next: (data) => {
                if (data && data.data && data.data.fields) {
                  this.data = data;
                  this.updateChart();
                } else {
                  this.handleOperationError('js.gantt.logs.data_refetch_failed');
                  this.updateChart();
                }
                clearLockAndUpdate();
              },
              error: () => {
                this.handleOperationError('js.gantt.logs.data_refetch_api_error');
                this.updateChart();
                clearLockAndUpdate();
              }
            });
          } else {
            this.planService.getPlanData(planId).subscribe({
              next: (data) => {
                if (data && data.data && data.data.fields) {
                  this.data = data;
                  this.updateChart();
                } else {
                  this.handleOperationError('js.gantt.logs.data_refetch_failed');
                  this.updateChart();
                }
                clearLockAndUpdate();
              },
              error: () => {
                this.handleOperationError('js.gantt.logs.data_refetch_api_error');
                this.updateChart();
                clearLockAndUpdate();
              }
            });
          }
        } else {
          this.handleAdjustmentFailure(response.message);
        }
      },
      error: (error: HttpErrorResponse) => {
        this.handleAdjustmentFailure(this.extractHttpErrorMessage(error));
      }
    });
  }

  toggleCropPalette() {
    this.isCropPaletteOpen = !this.isCropPaletteOpen;
    if (this.isCropPaletteOpen) {
      this.cropStartDate = this.data?.data?.planning_start_date ?? this.cropStartDate;
      this.selectedCrop = null;
    } else {
      this.selectedCrop = null;
      this.cropStartDate = null;
    }
  }

  selectCrop(crop: AvailableCropData) {
    this.selectedCrop = crop;
    this.confirmAddCrop();
  }

  confirmAddCrop() {
    if (!this.data || !this.selectedCrop) return;
    const planId = this.data.data.id;
    const endpoint = this.planService.buildCultivationPlanEndpoint(this.planType, planId, 'add_crop');
    if (!endpoint) return;
    this.isAddCropLoading = true;
    this.showOptimizationLock = true;
    const displayRange = this.buildAddCropDisplayRange();
    const payload: AddCropRequest = {
      crop_id: this.selectedCrop.id,
      ...(displayRange.start && { display_start_date: displayRange.start }),
      ...(displayRange.end && { display_end_date: displayRange.end })
    };

    this.planService.addCrop(endpoint, payload).subscribe({
      next: (response) => {
        this.isAddCropLoading = false;
        if (response.success) {
          this.isCropPaletteOpen = false;
          this.selectedCrop = null;
          this.cropStartDate = null;
          this.refreshPlanData(planId);
        } else {
          this.handleOperationError(response.message, response.technical_details);
        }
      },
      error: (error: HttpErrorResponse) => {
        this.isAddCropLoading = false;
        this.handleOperationError(this.extractHttpErrorMessage(error));
      }
    });
  }

  private buildAddCropDisplayRange(): { start?: string; end?: string } {
    const { start: planStart, end: planEnd } = this.getPlanBoundsFromData();
    const effectiveStart = this.visibleStartDate ?? planStart;
    const effectiveEnd = this.visibleEndDate ?? planEnd;
    return {
      start: this.formatDisplayRangeDate(effectiveStart),
      end: this.formatDisplayRangeDate(effectiveEnd)
    };
  }

  private getPlanBoundsFromData(): { start: Date | null; end: Date | null } {
    if (!this.data) return { start: null, end: null };
    const planStartRaw = new Date(this.data.data.planning_start_date);
    const planEndRaw = new Date(this.data.data.planning_end_date);

    if (isNaN(planStartRaw.getTime()) || isNaN(planEndRaw.getTime())) {
      return { start: null, end: null };
    }

    const { start, end } = normalizePlanBounds(planStartRaw, planEndRaw);
    return { start, end };
  }

  private formatDisplayRangeDate(date?: Date | null): string | undefined {
    if (!date) return undefined;
    return formatIsoDateOnly(date);
  }

  confirmRemoveCultivation(cultivation: CultivationData) {
    if (!this.data) return;
    const planId = this.data.data.id;
    const endpoint = this.planService.buildCultivationPlanEndpoint(this.planType, planId, 'adjust');
    if (!endpoint) return;
    this.showOptimizationLock = true;

    this.planService.removeCultivation(endpoint, {
      moves: [{ allocation_id: cultivation.id, action: 'remove' }]
    }).subscribe({
      next: (response) => {
        if (response.success) {
          this.refreshPlanData(planId);
        } else {
          this.handleOperationError(response.message);
        }
      },
      error: (error: HttpErrorResponse) => {
        this.handleOperationError(this.extractHttpErrorMessage(error));
      }
    });
  }

  toggleFieldForm() {
    this.fieldFormVisible = !this.fieldFormVisible;
    if (!this.fieldFormVisible) {
      this.newFieldName = '';
      this.newFieldArea = null;
    }
  }

  confirmAddField() {
    if (!this.data || !this.newFieldName || !this.newFieldArea) return;
    const planId = this.data.data.id;
    const endpoint = this.planService.buildCultivationPlanEndpoint(this.planType, planId, 'add_field');
    if (!endpoint) return;
    this.isFieldFormLoading = true;
    this.showOptimizationLock = true;
    const payload = {
      field_name: this.newFieldName,
      field_area: Number(this.newFieldArea)
    };

    this.planService.addField(endpoint, payload).subscribe({
      next: (response) => {
        this.isFieldFormLoading = false;
        if (response.success) {
          this.fieldFormVisible = false;
          this.newFieldName = '';
          this.newFieldArea = null;
          this.refreshPlanData(planId);
        } else {
          this.handleOperationError(response.message);
        }
      },
      error: (error: HttpErrorResponse) => {
        this.isFieldFormLoading = false;
        this.handleOperationError(this.extractHttpErrorMessage(error));
      }
    });
  }

  confirmRemoveField(group: GanttFieldGroup) {
    if (!this.data || group.cultivations.length > 0) return;
    const planId = this.data.data.id;
    const endpoint = this.planService.buildCultivationPlanEndpoint(
      this.planType,
      planId,
      'remove_field',
      group.fieldId
    );
    if (!endpoint) return;
    this.showOptimizationLock = true;

    this.planService.removeField(endpoint).subscribe({
      next: (response) => {
        if (response.success) {
          this.refreshPlanData(planId);
        } else {
          this.handleOperationError(response.message);
        }
      },
      error: (error: HttpErrorResponse) => {
        this.handleOperationError(this.extractHttpErrorMessage(error));
      }
    });
  }

  private refreshPlanData(planId?: number) {
    const targetPlanId = planId ?? this.data?.data?.id;
    if (!targetPlanId) {
      this.showOptimizationLock = false;
      return;
    }

    const request$ = this.planType === 'public'
      ? this.planService.getPublicPlanData(targetPlanId)
      : this.planService.getPlanData(targetPlanId);

    request$.subscribe({
      next: (planData) => {
        if (planData) {
          this.data = planData;
          this.updateChart();
        }
        this.showOptimizationLock = false;
        this.scheduleDetectChanges();
      },
      error: (error: HttpErrorResponse) => {
        this.handleOperationError(this.extractHttpErrorMessage(error));
      }
    });
  }

  private handleOperationError(message?: string, technicalDetails?: string) {
    let text = message
      ? this.translate.instant(message)
      : this.translate.instant('plans.gantt.adjust_failed');
    if (technicalDetails) {
      text = `${text} (${technicalDetails})`;
    }
    this.flashMessageService.show({
      type: 'error',
      text
    });
    this.isAddCropLoading = false;
    this.isFieldFormLoading = false;
    this.showOptimizationLock = false;
    this.scheduleDetectChanges();
  }
}
