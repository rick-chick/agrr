import {
  Component,
  EventEmitter,
  Input,
  OnChanges,
  OnInit,
  Output,
  SimpleChanges,
  ElementRef,
  ViewChild,
  AfterViewInit,
  OnDestroy,
  inject,
  ChangeDetectorRef
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { CultivationPlanData, CultivationData, AvailableCropData } from '../../domain/plans/cultivation-plan-data';
import { CultivationPlanContextType } from '../../domain/plans/cultivation-plan-context-type';
import {
  addMonths,
  buildGanttFieldGroups,
  buildGanttTimeAxisSegments,
  buildGanttVisibleRangeFromStart,
  clampGanttChartWidth,
  computeGanttBarLabelPosition,
  computeGanttBarParamsForPlanView,
  computeGanttChartHeight,
  determineGanttTimeScale,
  GanttFieldGroup,
  GanttTimeAxisSegment,
  GanttTimeScale,
  GanttTimeUnit,
  ganttCropFillColor,
  ganttCropStrokeColor,
  applyGanttCultivationMove,
  normalizePlanBounds,
  formatGanttFieldRowIndexLabel,
  getGanttFieldLabelCenterX,
  getGanttMarginLeft,
  resolveGanttDragCommit,
  pickGanttActiveTouchIndex,
  collectTouchIdentifiers,
  computeGanttPointerDragDistancePx,
  shouldShowGanttTrashDropzone,
  resolveGanttMobileDragFieldContext,
  computeGanttDragPointerSvgOffset,
  computeGanttDragBarSvgPosition,
  resolveGanttEffectiveDisplayRange,
  buildGanttDragDropLayout,
  shouldActivateGanttDrag,
  shouldIgnoreGanttPointerCancel,
  shouldReinitializeGanttVisibleRange,
  DEFAULT_GANTT_CHART_DIMENSIONS,
  GanttChartDimensions,
  GanttVisibleRange,
  parseGanttPlanBounds,
  buildGanttAddCropDisplayRange,
  isPointInsideClientRect
} from '../../domain/plans/gantt-chart-layout';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { GanttAddCropRequest } from '../../usecase/plans/gantt-plan-mutation.dtos';
import { GanttChartView, GanttChartViewControl } from './gantt-chart.view';
import { GanttMobileActionsMenuComponent } from './gantt-mobile-actions-menu.component';
import { FlashMessageService } from '../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../core/view-effects/pending-error-flash-view.effects';
import { GanttChartPresenter } from '../../usecase/plans/gantt-chart.providers';
import { LoadGanttPlanDataUseCase } from '../../usecase/plans/load-gantt-plan-data.usecase';
import { RunGanttPlanMutationUseCase } from '../../usecase/plans/run-gantt-plan-mutation.usecase';

@Component({
  selector: 'app-gantt-chart',
  standalone: true,
  imports: [CommonModule, TranslateModule, FormsModule, GanttMobileActionsMenuComponent],
  template: `
    @if (showOptimizationLock) {
      <div class="screen-lock-overlay" aria-live="polite">
        <div class="screen-lock-content">
          <div class="spinner"></div>
          <p>{{ 'plans.gantt.optimizing' | translate }}</p>
        </div>
      </div>
    }
    <div class="gantt-page" [class.gantt-page--touch-drag]="isMobileLayout && draggedCultivation">
      <div class="gantt-action-bar">
        @if (isMobileLayout) {
          <div class="gantt-action-bar__primary-actions">
            <button
              class="action-button action-button--icon gantt-action-bar__crop-primary"
              type="button"
              (click)="mobileActionsMenu.closeMenu(); toggleCropPalette()"
              [class.active]="isCropPaletteOpen"
              [attr.aria-label]="
                (isCropPaletteOpen ? 'js.gantt.crop_palette_cancel' : 'js.gantt.add_crop_button') | translate
              ">
              @if (!isCropPaletteOpen) {
                <svg class="action-button__icon" viewBox="0 0 24 24" aria-hidden="true">
                  <path fill="currentColor" d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" />
                </svg>
              } @else {
                <svg class="action-button__icon" viewBox="0 0 24 24" aria-hidden="true">
                  <path
                    fill="currentColor"
                    d="M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
                </svg>
              }
            </button>
            <app-gantt-mobile-actions-menu
              #mobileActionsMenu
              [fieldFormVisible]="fieldFormVisible"
              [fieldLegendOpen]="fieldLegendOpen"
              (addFieldToggle)="toggleFieldForm()"
              (fieldLegendToggle)="toggleFieldLegend()"
            />
          </div>
        } @else {
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
        }
        <div class="gantt-range-controls">
          <button
            class="range-button"
            [class.range-button--icon]="isMobileLayout"
            type="button"
            (click)="shiftVisibleRange(-1)"
            [attr.aria-label]="isMobileLayout ? ('plans.gantt.range.prev_month' | translate) : null">
            @if (isMobileLayout) {
              <svg class="range-button__icon" viewBox="0 0 24 24" aria-hidden="true">
                <path
                  fill="currentColor"
                  d="M15.41 7.41 14 6l-6 6 6 6 1.41-1.41L10.83 12z" />
              </svg>
            } @else {
              {{ 'plans.gantt.range.prev_month' | translate }}
            }
          </button>
          <div class="gantt-range-label">
            <strong class="gantt-range-label__value">{{ visibleRangeLabel || '—' }}</strong>
          </div>
          <button
            class="range-button"
            [class.range-button--icon]="isMobileLayout"
            type="button"
            (click)="shiftVisibleRange(1)"
            [attr.aria-label]="isMobileLayout ? ('plans.gantt.range.next_month' | translate) : null">
            @if (isMobileLayout) {
              <svg class="range-button__icon" viewBox="0 0 24 24" aria-hidden="true">
                <path
                  fill="currentColor"
                  d="M8.59 16.59 13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z" />
              </svg>
            } @else {
              {{ 'plans.gantt.range.next_month' | translate }}
            }
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

      @if (isMobileLayout && fieldLegendOpen) {
        <div class="gantt-field-legend">
          <p class="section-title">{{ 'plans.gantt.mobile.field_legend_title' | translate }}</p>
          <ul class="gantt-field-legend__list">
            @for (group of fieldGroups; track group.fieldId; let i = $index) {
              <li class="gantt-field-legend__item">
                <span class="gantt-field-legend__label">
                  {{ 'plans.gantt.mobile.field_legend_item' | translate: { index: formatGanttFieldRowIndexLabel(i), fieldName: group.fieldName } }}
                </span>
                @if (group.cultivations.length === 0) {
                  <button
                    class="gantt-field-legend__delete"
                    type="button"
                    (click)="confirmRemoveField(group)">
                    {{ 'plans.gantt.mobile.field_legend_delete' | translate }}
                  </button>
                }
              </li>
            }
          </ul>
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
          @if (isMobileLayout && dragFieldContext) {
            <div class="gantt-drag-context" aria-live="polite">
              {{
                'plans.gantt.mobile.drag_target_field'
                  | translate: { index: dragFieldContext.rowIndex, fieldName: dragFieldContext.fieldName }
              }}
            </div>
          }
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
              <text
                [attr.x]="getGanttFieldLabelCenterX(config.margin.left)"
                y="30"
                class="header-label"
                text-anchor="middle"
                font-size="14"
                font-weight="bold"
                fill="#374151">
                @if (isMobileLayout) {
                  {{ 'plans.gantt.mobile.field_column_short' | translate }}
                } @else {
                  {{ 'shared.navbar.farms' | translate }}
                }
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
                <text
                  [attr.x]="getGanttFieldLabelCenterX(config.margin.left)"
                  [attr.y]="config.rowHeight / 2 + 5"
                  class="field-label"
                  text-anchor="middle"
                  font-size="14"
                  font-weight="600"
                  fill="#374151">
                  @if (isMobileLayout) {
                    {{ formatGanttFieldRowIndexLabel(i) }}
                  } @else {
                    {{ group.fieldName }}
                  }
                </text>
                <line [attr.x1]="config.margin.left - 10" y1="0" [attr.x2]="config.margin.left - 10" [attr.y2]="config.rowHeight" stroke="#D1D5DB" stroke-width="2" />
                @if (group.cultivations.length === 0 && !isMobileLayout) {
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
                            [attr.fill]="ganttCropFillColor(cultivation.crop_name)"
                            [attr.stroke]="ganttCropStrokeColor(cultivation.crop_name)"
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
export class GanttChartComponent
  implements OnInit, OnChanges, AfterViewInit, OnDestroy, GanttChartView
{
  readonly formatGanttFieldRowIndexLabel = formatGanttFieldRowIndexLabel;
  readonly getGanttFieldLabelCenterX = getGanttFieldLabelCenterX;
  readonly ganttCropFillColor = ganttCropFillColor;
  readonly ganttCropStrokeColor = ganttCropStrokeColor;
  @Input() data: CultivationPlanData | null = null;
  @Input() planType: CultivationPlanContextType = 'private';
  @Output() cultivationSelected = new EventEmitter<{
    cultivationId: number;
    planType: CultivationPlanContextType;
  }>();
  @Output() visibleRangeChange = new EventEmitter<GanttVisibleRange>();

  @ViewChild('container') container!: ElementRef<HTMLDivElement>;
  @ViewChild('svg') svgElement!: ElementRef<SVGSVGElement>;
  @ViewChild('highlightRect') highlightRect!: ElementRef<SVGRectElement>;
  @ViewChild('trashDropzone') trashDropzone?: ElementRef<HTMLElement>;

  /** max-width: 768px — matches project mobile breakpoints */
  isMobileLayout = false;
  fieldLegendOpen = false;
  dragFieldContext: { rowIndex: number; fieldName: string } | null = null;
  showTrashDropzone = false;
  trashDropzoneActive = false;

  config: GanttChartDimensions = { ...DEFAULT_GANTT_CHART_DIMENSIONS };

  fieldGroups: GanttFieldGroup[] = [];
  months: GanttTimeAxisSegment[] = [];
  timeScale: GanttTimeScale = { unit: GanttTimeUnit.Month, interval: 1 };
  isCropPaletteOpen = false;
  selectedCrop: AvailableCropData | null = null;

  fieldFormVisible = false;
  newFieldName = '';
  newFieldArea: number | null = null;
  isFieldFormLoading = false;

  visibleStartDate: Date | null = null;
  visibleEndDate: Date | null = null;
  visibleRangeLabel = '';

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
      this.fieldLegendOpen = false;
      this.dragFieldContext = null;
    }
    this.applyLayoutMargins();
    this.updateDimensions();
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
  private globalTouchMoveHandler: ((event: TouchEvent) => void) | null = null;
  private svgTouchStartHandler: ((event: TouchEvent) => void) | null = null;
  /** touch.identifier（pointerId と一致しない端末向け） */
  private activeTouchIdentifier: number | null = null;
  private savedBodyOverflow: string | null = null;
  private savedBodyTouchAction: string | null = null;
  private dragPointerEnded = false;
  private needsUpdate = false; // データ変更とコンテナ準備のタイミングを分離するためのフラグ
  private isDestroyed = false;
  private pendingDetectChanges = false;
  /** ドロップ後の最適化API完了までオーバーレイを表示する */
  showOptimizationLock = false;
  private loadGanttPlanDataUseCase = inject(LoadGanttPlanDataUseCase);
  private runGanttPlanMutationUseCase = inject(RunGanttPlanMutationUseCase);
  private ganttPresenter = inject(GanttChartPresenter);
  private flashMessage = inject(FlashMessageService);
  private cdr = inject(ChangeDetectorRef);

  private _control: GanttChartViewControl = { pendingErrorFlash: null };
  get control(): GanttChartViewControl {
    return this._control;
  }
  set control(value: GanttChartViewControl) {
    this._control = applyPendingErrorFlashViewEffects(value, { flash: this.flashMessage });
    this.cdr.markForCheck();
  }

  constructor(private translate: TranslateService) {}

  ngOnInit(): void {
    this.ganttPresenter.setView(this);
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
      this.applyLayoutMargins();
      this.mobileMediaQuery.addEventListener('change', this.onMobileLayoutChange);
    }
  }

  ngOnDestroy(): void {
    window.removeEventListener('resize', this.onResize);
    this.mobileMediaQuery?.removeEventListener('change', this.onMobileLayoutChange);
    this.unbindSvgTouchStartGuard();
    this.unlockMobilePageScroll();
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

  toggleFieldLegend(): void {
    this.fieldLegendOpen = !this.fieldLegendOpen;
  }

  private applyLayoutMargins(): void {
    this.config.margin.left = getGanttMarginLeft(this.isMobileLayout);
  }

  private syncDragFieldContext(targetFieldIndex: number): void {
    this.dragFieldContext = resolveGanttMobileDragFieldContext({
      isMobileLayout: this.isMobileLayout,
      isDragging: this.isDragging,
      targetFieldIndex,
      originalFieldIndex: this.originalFieldIndex,
      fieldGroups: this.fieldGroups
    });
  }

  private clearDragFieldContext(): void {
    this.dragFieldContext = null;
  }

  private updateDimensions() {
    this.applyLayoutMargins();
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

    this.applyLayoutMargins();

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
    setTimeout(() => this.bindSvgTouchStartGuard(), 0);
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
    const range = buildGanttVisibleRangeFromStart(candidateStart);
    if (!range) {
      return;
    }
    this.visibleStartDate = range.startDate;
    this.visibleEndDate = range.endDate;
    this.visibleRangeLabel = range.label;
    this.emitVisibleRange();
  }

  private emitVisibleRange() {
    if (!this.visibleStartDate || !this.visibleEndDate) return;
    this.visibleRangeChange.emit({
      startDate: new Date(this.visibleStartDate),
      endDate: new Date(this.visibleEndDate),
      label: this.visibleRangeLabel
    });
  }

  getBarParams(cultivation: CultivationData) {
    if (!this.data) return null;

    return computeGanttBarParamsForPlanView({
      cultivationStart: cultivation.start_date,
      cultivationEnd: cultivation.completion_date,
      planningStartDate: this.data.data.planning_start_date,
      planningEndDate: this.data.data.planning_end_date,
      visibleStart: this.visibleStartDate,
      visibleEnd: this.visibleEndDate,
      marginLeft: this.config.margin.left,
      chartWidth: this.config.width - this.config.margin.left - this.config.margin.right
    });
  }

  onPointerDown(event: PointerEvent, cultivation: CultivationData) {
    if (event.button !== 0) return;
    event.preventDefault();

    this.capturePointerOnSvg(event.pointerId);
    this.activePointerId = event.pointerId;
    this.dragPointerEnded = false;
    if (this.isMobileLayout) {
      this.lockMobilePageScroll();
    }

    this.isDragging = false;
    this.pointerDragDistance = 0;
    this.resetTrashDropzoneState();
    this.draggedCultivation = cultivation;
    this.dragStartX = event.clientX;
    this.dragStartY = event.clientY;

    const barGroup = this.getBarGroupElement(cultivation.id);
    if (barGroup) {
      const barBg = barGroup.querySelector('.bar-bg') as SVGRectElement;
      if (barBg) {
        this.originalBarX = parseFloat(barBg.getAttribute('x') || '0');
        const originalBarY = parseFloat(barBg.getAttribute('y') || '0');
        barBg.setAttribute('data-original-y', originalBarY.toString());
        this.originalBarY = originalBarY;
      }
    }

    if (this.data) {
      const { start: planStart, end: planEnd } = normalizePlanBounds(
        new Date(this.data.data.planning_start_date),
        new Date(this.data.data.planning_end_date)
      );
      this.dragStartDisplayStartDate = this.visibleStartDate ?? planStart;
      this.dragStartDisplayEndDate = this.visibleEndDate ?? planEnd;
    }

    this.originalFieldIndex = this.fieldGroups.findIndex((g) => g.fieldName === cultivation.field_name);
    this.lastTargetFieldIndex = -1;
    this.clearDragFieldContext();

    this.globalPointerMoveHandler = (e: PointerEvent) => this.onPointerMove(e);
    this.globalPointerUpHandler = (e: PointerEvent) => this.onPointerUp(e);
    this.globalPointerCancelHandler = (e: PointerEvent) => this.onPointerCancel(e);

    document.addEventListener('pointermove', this.globalPointerMoveHandler);
    document.addEventListener('pointerup', this.globalPointerUpHandler);
    document.addEventListener('pointercancel', this.globalPointerCancelHandler);
    if (this.isMobileLayout) {
      this.globalTouchMoveHandler = (e: TouchEvent) => this.onTouchMove(e);
      this.globalTouchEndHandler = (e: TouchEvent) => this.onTouchEnd(e);
      document.addEventListener('touchmove', this.globalTouchMoveHandler, { passive: false });
      document.addEventListener('touchend', this.globalTouchEndHandler);
    }
  }

  private capturePointerOnSvg(pointerId: number): void {
    const captureTarget = this.svgElement?.nativeElement;
    if (!captureTarget?.setPointerCapture) return;
    try {
      captureTarget.setPointerCapture(pointerId);
    } catch {
      // ignore capture failures on unsupported targets
    }
  }

  private bindSvgTouchStartGuard(): void {
    const svg = this.svgElement?.nativeElement;
    if (!svg || this.svgTouchStartHandler) return;

    this.svgTouchStartHandler = (event: TouchEvent) => this.onSvgTouchStart(event);
    svg.addEventListener('touchstart', this.svgTouchStartHandler, { capture: true });
  }

  private unbindSvgTouchStartGuard(): void {
    const svg = this.svgElement?.nativeElement;
    if (!svg || !this.svgTouchStartHandler) return;

    svg.removeEventListener('touchstart', this.svgTouchStartHandler, { capture: true });
    this.svgTouchStartHandler = null;
  }

  /**
   * touchstart は pointerdown より先に届く。バー上で preventDefault しないと
   * ブラウザが縦スクロールを奪い pointercancel → バーが指に追随しなくなる。
   */
  private onSvgTouchStart(event: TouchEvent): void {
    if (!this.isMobileLayout) return;

    const bar = (event.target as Element | null)?.closest('.cultivation-bar');
    if (!bar) return;

    const touch = event.touches.item(0);
    if (touch) {
      this.activeTouchIdentifier = touch.identifier;
    }
  }

  private lockMobilePageScroll(): void {
    if (this.savedBodyOverflow !== null) return;
    this.savedBodyOverflow = document.body.style.overflow;
    this.savedBodyTouchAction = document.body.style.touchAction;
    document.body.style.overflow = 'hidden';
    document.body.style.touchAction = 'none';
  }

  private unlockMobilePageScroll(): void {
    if (this.savedBodyOverflow === null) return;
    document.body.style.overflow = this.savedBodyOverflow;
    document.body.style.touchAction = this.savedBodyTouchAction ?? '';
    this.savedBodyOverflow = null;
    this.savedBodyTouchAction = null;
  }

  private onTouchMove(event: TouchEvent) {
    if (!this.isMobileLayout || !this.draggedCultivation || this.dragPointerEnded) return;
    event.preventDefault();

    const touch = this.pickActiveTouchFromList(event.touches);
    if (!touch) return;

    if (this.activeTouchIdentifier === null) {
      this.activeTouchIdentifier = touch.identifier;
    }

    this.applyDragFromScreenCoords(touch.clientX, touch.clientY);
  }

  private pickActiveTouchFromList(touchList: TouchList): Touch | null {
    const identifiers = collectTouchIdentifiers(touchList.length, (index) => {
      const touch = touchList.item(index);
      return touch?.identifier;
    });
    const activeId = this.activeTouchIdentifier ?? this.activePointerId;
    const index = pickGanttActiveTouchIndex(identifiers, activeId);
    if (index === null) return null;
    return touchList.item(index);
  }

  private onPointerMove(event: PointerEvent) {
    if (!this.draggedCultivation) return;
    if (this.activePointerId !== null && event.pointerId !== this.activePointerId) return;

    if (this.isDragging && this.isMobileLayout) {
      event.preventDefault();
    }

    const activated = this.applyDragFromScreenCoords(event.clientX, event.clientY);
    if (activated && this.isMobileLayout) {
      event.preventDefault();
    }
  }

  /** @returns true when drag activation threshold was crossed this call */
  private applyDragFromScreenCoords(clientX: number, clientY: number): boolean {
    if (!this.draggedCultivation) return false;

    this.pointerDragDistance = computeGanttPointerDragDistancePx(
      clientX,
      clientY,
      this.dragStartX,
      this.dragStartY
    );
    this.updateTrashDropzoneUi(clientX, clientY);

    let justActivated = false;
    if (!this.isDragging) {
      if (!shouldActivateGanttDrag(this.pointerDragDistance, this.isMobileLayout)) {
        return false;
      }
      this.isDragging = true;
      justActivated = true;

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

          this.barWidth = parseFloat(this.cachedBarBg.getAttribute('width') || '0');
          this.barHeight = parseFloat(this.cachedBarBg.getAttribute('height') || '0');

          const startSvgCoords = this.screenToSVGCoords(this.dragStartX, this.dragStartY);
          const currentBarY = parseFloat(this.cachedBarBg.getAttribute('y') || '0');
          this.initialMouseSvgOffset = computeGanttDragPointerSvgOffset({
            pointerSvgX: startSvgCoords.x,
            pointerSvgY: startSvgCoords.y,
            originalBarX: this.originalBarX,
            currentBarY
          });
        }
      }
    }

    const currentSvgCoords = this.screenToSVGCoords(clientX, clientY);
    const originalBarY = this.cachedBarBg
      ? parseFloat(this.cachedBarBg.getAttribute('data-original-y') || '0')
      : this.originalBarY;
    const dragPosition = computeGanttDragBarSvgPosition({
      pointerSvgX: currentSvgCoords.x,
      pointerSvgY: currentSvgCoords.y,
      initialOffset: this.initialMouseSvgOffset,
      originalBarY,
      originalFieldIndex: this.originalFieldIndex,
      rowHeight: this.config.rowHeight,
      fieldCount: this.fieldGroups.length,
      headerHeight: this.config.margin.top
    });

    if (dragPosition.targetFieldIndex !== this.lastTargetFieldIndex && this.highlightRect) {
      if (dragPosition.rowHighlight.visible) {
        this.highlightRect.nativeElement.setAttribute('y', dragPosition.rowHighlight.y.toString());
        this.highlightRect.nativeElement.setAttribute(
          'height',
          dragPosition.rowHighlight.height.toString()
        );
        this.highlightRect.nativeElement.setAttribute(
          'opacity',
          dragPosition.rowHighlight.opacity.toString()
        );
      } else {
        this.highlightRect.nativeElement.setAttribute('opacity', '0');
      }

      this.lastTargetFieldIndex = dragPosition.targetFieldIndex;
      this.syncDragFieldContext(dragPosition.targetFieldIndex);
    }

    if (this.cachedBarBg) {
      this.cachedBarBg.setAttribute('x', dragPosition.barX.toString());
      this.cachedBarBg.setAttribute('y', dragPosition.barY.toString());

      if (this.cachedLabel) {
        const label = computeGanttBarLabelPosition({
          barX: dragPosition.barX,
          barWidth: this.barWidth,
          labelReserve: 0,
          barY: dragPosition.barY,
          barHeight: this.barHeight
        });
        this.cachedLabel.setAttribute('x', label.x.toString());
        this.cachedLabel.setAttribute('y', label.y.toString());
      }
    }

    return justActivated;
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

    const changedTouchIds = collectTouchIdentifiers(event.changedTouches.length, (index) => {
      const touch = event.changedTouches.item(index);
      return touch?.identifier;
    });
    const activeId = this.activeTouchIdentifier ?? this.activePointerId;
    const touchIndex = pickGanttActiveTouchIndex(changedTouchIds, activeId);
    if (touchIndex === null) return;

    const touch = event.changedTouches.item(touchIndex);
    if (!touch) return;

    this.dragPointerEnded = true;
    this.activePointerId = null;
    this.activeTouchIdentifier = null;
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

    if (this.isDragging && this.isPointerOverTrash(clientX, clientY)) {
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
    const layout = buildGanttDragDropLayout({
      marginLeft: this.config.margin.left,
      chartWidth: this.config.width - this.config.margin.left - this.config.margin.right,
      rowHeight: this.config.rowHeight,
      displayStart: displayRange.start,
      displayEnd: displayRange.end
    });

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
        const cultivation = this.data.data.cultivations.find((c) => c.id === cultivationId);
        if (cultivation) {
          applyGanttCultivationMove({
            cultivation,
            fieldGroups: this.fieldGroups,
            newFieldName: commit.newFieldName,
            newFieldIndex: commit.newFieldIndex,
            newStartDate: commit.newStartDate
          });
          this.updateChart();
        }

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
    if (this.globalTouchMoveHandler) {
      document.removeEventListener('touchmove', this.globalTouchMoveHandler);
      this.globalTouchMoveHandler = null;
    }
    if (this.globalTouchEndHandler) {
      document.removeEventListener('touchend', this.globalTouchEndHandler);
      this.globalTouchEndHandler = null;
    }
    this.activeTouchIdentifier = null;
    this.unlockMobilePageScroll();
  }

  private releaseActivePointerCapture(event: PointerEvent): void {
    const captureTarget = this.svgElement?.nativeElement;
    if (captureTarget?.releasePointerCapture) {
      try {
        if (captureTarget.hasPointerCapture?.(event.pointerId)) {
          captureTarget.releasePointerCapture(event.pointerId);
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
      const label = computeGanttBarLabelPosition({
        barX: this.originalBarX,
        barWidth: this.barWidth,
        labelReserve: 0,
        barY: originalBarY,
        barHeight: this.barHeight
      });
      this.cachedLabel.setAttribute('x', label.x.toString());
      this.cachedLabel.setAttribute('y', label.y.toString());
    }
  }

  private updateTrashDropzoneUi(clientX: number, clientY: number) {
    if (
      !shouldShowGanttTrashDropzone({
        isMobileLayout: this.isMobileLayout,
        isDragging: this.isDragging,
        pointerDragDistance: this.pointerDragDistance
      }) ||
      !this.draggedCultivation
    ) {
      this.clearTrashDropzoneUi();
      return;
    }
    if (!this.showTrashDropzone) {
      this.showTrashDropzone = true;
      this.scheduleDetectChanges();
    }
    const overTrash = this.isPointerOverTrash(clientX, clientY);
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
    return isPointInsideClientRect(clientX, clientY, el.getBoundingClientRect());
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

  resetBarPosition(): void {
    if (!this.data) return;
    this.loadGanttPlanDataUseCase.execute({
      planType: this.planType,
      planId: this.data.data.id,
      purpose: 'reset_bar'
    });
  }

  requestPlanRefresh(planId: number): void {
    this.loadGanttPlanDataUseCase.execute({
      planType: this.planType,
      planId,
      purpose: 'refresh'
    });
  }

  applyBarResetPlanData(planData: CultivationPlanData): void {
    this.data = planData;
    this.updateChart();
  }

  private getBarGroupElement(cultivationId: number): SVGGElement | null {
    const svg = this.svgElement?.nativeElement;
    if (!svg) return null;
    return svg.querySelector(`g.cultivation-bar[data-id="${cultivationId}"]`) as SVGGElement;
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
    this.clearDragFieldContext();
  }

  private getEffectiveDisplayRange(): { start: Date; end: Date } {
    const { start: planStart, end: planEnd } = parseGanttPlanBounds(
      this.data?.data?.planning_start_date,
      this.data?.data?.planning_end_date
    );
    return resolveGanttEffectiveDisplayRange({
      dragStartDisplayStart: this.dragStartDisplayStartDate,
      dragStartDisplayEnd: this.dragStartDisplayEndDate,
      visibleStart: this.visibleStartDate,
      visibleEnd: this.visibleEndDate,
      planStart,
      planEnd
    });
  }

  private adjustCultivation(
    cultivationId: number,
    _newFieldName: string,
    newFieldIndex: number,
    newStartDate: Date
  ) {
    if (!this.data) return;

    const planId = this.data.data.id;
    const targetField = this.fieldGroups[newFieldIndex];
    if (!targetField) return;

    this.runGanttPlanMutationUseCase.execute({
      planType: this.planType,
      planId,
      command: {
        kind: 'adjustCultivationMove',
        cultivationId,
        toFieldId: targetField.fieldId,
        newStartDate
      },
      presentation: {
        onRefetchFailure: 'update_chart',
        revertBarOnMessageFailure: true
      }
    });
  }

  toggleCropPalette() {
    this.isCropPaletteOpen = !this.isCropPaletteOpen;
    this.selectedCrop = null;
  }

  selectCrop(crop: AvailableCropData) {
    this.selectedCrop = crop;
    this.confirmAddCrop();
  }

  confirmAddCrop() {
    if (!this.data || !this.selectedCrop) return;
    const planId = this.data.data.id;
    this.showOptimizationLock = true;
    const { start: planStart, end: planEnd } = parseGanttPlanBounds(
      this.data.data.planning_start_date,
      this.data.data.planning_end_date
    );
    const displayRange = buildGanttAddCropDisplayRange({
      visibleStart: this.visibleStartDate,
      visibleEnd: this.visibleEndDate,
      planStart,
      planEnd
    });
    const payload: GanttAddCropRequest = {
      crop_id: this.selectedCrop.id,
      ...(displayRange.start && { display_start_date: displayRange.start }),
      ...(displayRange.end && { display_end_date: displayRange.end })
    };

    this.runGanttPlanMutationUseCase.execute({
      planType: this.planType,
      planId,
      command: { kind: 'addCrop', payload },
      presentation: {
        onSuccess: (data) => {
          this.isCropPaletteOpen = false;
          this.selectedCrop = null;
          this.applyRefreshedPlanData(data);
        }
      }
    });
  }

  confirmRemoveCultivation(cultivation: CultivationData) {
    if (!this.data) return;
    const confirmed = confirm(
      this.translate.instant('js.gantt.confirm_delete_crop', {
        crop_name: cultivation.crop_name
      })
    );
    if (!confirmed) return;

    const planId = this.data.data.id;
    this.showOptimizationLock = true;

    this.runGanttPlanMutationUseCase.execute({
      planType: this.planType,
      planId,
      command: { kind: 'removeCultivation', cultivationId: cultivation.id }
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
    this.isFieldFormLoading = true;
    this.showOptimizationLock = true;

    this.runGanttPlanMutationUseCase.execute({
      planType: this.planType,
      planId,
      command: {
        kind: 'addField',
        payload: {
          field_name: this.newFieldName,
          field_area: Number(this.newFieldArea)
        }
      },
      presentation: {
        onSuccess: (data) => {
          this.fieldFormVisible = false;
          this.newFieldName = '';
          this.newFieldArea = null;
          this.applyRefreshedPlanData(data);
        }
      }
    });
  }

  confirmRemoveField(group: GanttFieldGroup) {
    if (!this.data || group.cultivations.length > 0) return;
    const confirmed = confirm(
      this.translate.instant('js.gantt.confirm_delete_field', {
        field_name: group.fieldName
      })
    );
    if (!confirmed) return;

    const planId = this.data.data.id;
    this.showOptimizationLock = true;

    this.runGanttPlanMutationUseCase.execute({
      planType: this.planType,
      planId,
      command: { kind: 'removeField', fieldId: group.fieldId }
    });
  }

  applyRefreshedPlanData(planData: CultivationPlanData): void {
    this.data = planData;
    this.updateChart();
    this.showOptimizationLock = false;
    this.scheduleDetectChanges();
  }

  updateChartOnly(): void {
    this.updateChart();
    this.showOptimizationLock = false;
    this.scheduleDetectChanges();
  }

  clearOptimizationLock(): void {
    this.showOptimizationLock = false;
    this.scheduleDetectChanges();
  }

  setFieldFormLoading(loading: boolean): void {
    this.isFieldFormLoading = loading;
  }
}
