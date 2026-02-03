import { Component, EventEmitter, Input, OnChanges, OnInit, Output, SimpleChanges, ElementRef, ViewChild, AfterViewInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { CultivationPlanData, CultivationData } from '../../domain/plans/cultivation-plan-data';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { PlanService } from '../../services/plans/plan.service';
import { FlashMessageService } from '../../services/flash-message.service';

interface GanttConfig {
  margin: { top: number; right: number; bottom: number; left: number };
  rowHeight: number;
  barHeight: number;
  barPadding: number;
  width: number;
  height: number;
}

interface FieldGroup {
  fieldName: string;
  fieldId: number;
  cultivations: CultivationData[];
}

enum TimeUnit {
  Day = 'day',
  Week = 'week',
  Month = 'month',
  Quarter = 'quarter'
}

interface TimeScale {
  unit: TimeUnit;
  label: string;
  interval: number; // 何単位ごとにラベルを表示するか
}

@Component({
  selector: 'app-gantt-chart',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    @if (showOptimizationLock) {
      <div class="screen-lock-overlay" aria-live="polite">
        <div class="screen-lock-content">
          <div class="spinner"></div>
          <p>{{ 'plans.gantt.optimizing' | translate }}</p>
        </div>
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
            <p>APIレスポンス: {{ debugData() }}</p>
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
              
              <!-- Cultivation Bars -->
              @for (cultivation of group.cultivations; track cultivation.id) {
                @if (getBarParams(cultivation); as params) {
                  <g class="cultivation-bar" 
                     (mousedown)="onMouseDown($event, cultivation)"
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
                    <text [attr.x]="params.x + params.width / 2" 
                          [attr.y]="config.barPadding + config.barHeight / 2 + 5" 
                          class="bar-label" text-anchor="middle" font-size="12" font-weight="600" fill="#1F2937" style="pointer-events: none;">
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

  @ViewChild('container') container!: ElementRef<HTMLDivElement>;
  @ViewChild('svg') svgElement!: ElementRef<SVGSVGElement>;
  @ViewChild('highlightRect') highlightRect!: ElementRef<SVGRectElement>;

  config: GanttConfig = {
    margin: { top: 60, right: 20, bottom: 12, left: 80 },
    rowHeight: 68,
    barHeight: 48,
    barPadding: 8,
    width: 1200,
    height: 500
  };

  fieldGroups: FieldGroup[] = [];
  months: any[] = [];
  timeScale: TimeScale = { unit: TimeUnit.Month, label: '月', interval: 1 };
  
  private isDragging = false;
  draggedCultivation: CultivationData | null = null;
  private dragStartX = 0;
  private dragStartY = 0;
  private dragThreshold = 5; // 5px以上移動したらドラッグとみなす
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
  private globalMouseMoveHandler: any;
  private globalMouseUpHandler: any;
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
    console.log('🚀 GanttChartComponent: ngOnInit called', {
      hasData: !!this.data,
      dataStructure: this.data ? Object.keys(this.data) : null,
      fieldsCount: this.data?.data?.fields?.length,
      cultivationsCount: this.data?.data?.cultivations?.length
    });
    // コンテナ要素がまだ利用できないため、updateChart()は呼ばずにフラグを設定
    if (this.data) {
      this.needsUpdate = true;
    }
  }

  ngOnChanges(changes: SimpleChanges): void {
    console.log('🔄 GanttChartComponent: ngOnChanges called', {
      hasData: !!this.data,
      dataStructure: this.data ? Object.keys(this.data) : null,
      fieldsCount: this.data?.data?.fields?.length,
      cultivationsCount: this.data?.data?.cultivations?.length,
      containerReady: !!this.container?.nativeElement
    });
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
    // コンテナ要素が確実にレンダリングされた後に幅を取得し、必要に応じてupdateChart()を実行
    setTimeout(() => {
      this.updateDimensions();
      if (this.needsUpdate) {
        this.updateChart();
        this.needsUpdate = false;
      }
      // 初期描画後にChangeDetectionを実行して画面を更新
      this.scheduleDetectChanges();
    }, 0);
    window.addEventListener('resize', this.onResize);
  }

  ngOnDestroy(): void {
    window.removeEventListener('resize', this.onResize);
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
      this.config.width = Math.max(width, 400);
      if (this.data) {
        this.updateChart();
      }
    }
  }

  private updateChart() {
    console.log('📊 GanttChartComponent: updateChart called', {
      hasData: !!this.data,
      fieldsCount: this.data?.data?.fields?.length,
      cultivationsCount: this.data?.data?.cultivations?.length,
      containerWidth: this.container?.nativeElement?.getBoundingClientRect().width
    });

    if (!this.data) {
      console.warn('❌ GanttChartComponent: No data available');
      return;
    }

    // コンテナ幅を取得してconfig.widthを更新（スクロール防止）
    if (this.container?.nativeElement) {
      const width = this.container.nativeElement.getBoundingClientRect().width;
      if (width > 0) {
        this.config.width = Math.max(width, 400);
      }
    }

    const fields = this.data.data.fields;
    const cultivations = this.data.data.cultivations;

    console.log('📋 GanttChartComponent: Processing data', {
      fields: fields?.length || 0,
      cultivations: cultivations?.length || 0
    });

    // フィールドをID順でソートして、常に同じ順序で描画されるようにする
    // これにより、最適化後のフィールド順序変更によるy方向位置ズレを防ぐ
    const sortedFields = [...fields].sort((a, b) => a.id - b.id);

    this.fieldGroups = sortedFields.map(f => ({
      fieldName: f.name,
      fieldId: f.id,
      cultivations: cultivations.filter(c => c.field_id === f.id)
    }));

    this.config.height = this.config.margin.top + (this.fieldGroups.length * this.config.rowHeight) + this.config.margin.bottom;

    // chartWidthを計算してからdetermineTimeScaleに渡す
    const chartWidth = this.config.width - this.config.margin.left - this.config.margin.right;
    this.timeScale = this.determineTimeScale(
      new Date(this.data.data.planning_start_date),
      new Date(this.data.data.planning_end_date),
      chartWidth
    );
    this.calculateTimeAxis();

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
        const y = parseFloat(rect.getAttribute('y') || this.config.barPadding.toString());
        const height = parseFloat(rect.getAttribute('height') || this.config.barHeight.toString());
        t.setAttribute('x', (x + (width / 2)).toString());
        t.setAttribute('y', (y + (height / 2) + 5).toString());
      });
    } catch (e) {
      // 万が一SVG操作で例外が出ても描画は継続する
      console.error('sanitizeSvgBars error', e);
    }
  }

  private calculateTimeAxis() {
    if (!this.data) return;
    const start = new Date(this.data.data.planning_start_date);
    const end = new Date(this.data.data.planning_end_date);
    const totalDays = this.daysBetween(start, end);
    const chartWidth = this.config.width - this.config.margin.left - this.config.margin.right;

    this.months = [];
    let current = new Date(start);
    let x = this.config.margin.left;
    let unitIndex = 0;

    // 時間単位に応じて総数を計算
    // labelIntervalはdetermineTimeScale内で計算済み
    const labelInterval = this.timeScale.interval;

    while (current <= end) {
      const segment = this.getNextTimeSegment(current, this.timeScale.unit);
      if (!segment) break;

      const daysInSegment = this.daysBetween(current, segment.end);
      const width = (daysInSegment / totalDays) * chartWidth;

      // ラベルを表示するかどうかを決定
      const showLabel = unitIndex % labelInterval === 0;

      // 年ラベルを表示する条件（年初または最初のセグメント）
      const showYear = this.shouldShowYear(current, segment.end, this.timeScale.unit, unitIndex === 0);

      this.months.push({
        date: new Date(current),
        year: current.getFullYear(),
        month: current.getMonth() + 1,
        quarter: Math.floor(current.getMonth() / 3) + 1,
        week: this.getWeekNumber(current),
        day: current.getDate(),
        label: this.getTimeLabel(current, segment.end, this.timeScale.unit),
        showYear,
        showLabel,
        x,
        width
      });

      x += width;
      current = segment.end;
      unitIndex++;
    }
  }

  private getTotalUnits(start: Date, end: Date, unit: TimeUnit): number {
    switch (unit) {
      case TimeUnit.Day:
        return this.getTotalDays(start, end);
      case TimeUnit.Week:
        return Math.ceil(this.getTotalDays(start, end) / 7);
      case TimeUnit.Month:
        return this.getTotalMonths(start, end);
      case TimeUnit.Quarter:
        return Math.ceil(this.getTotalMonths(start, end) / 3);
      default:
        return this.getTotalMonths(start, end);
    }
  }

  private getNextTimeSegment(current: Date, unit: TimeUnit): { start: Date; end: Date } | null {
    const start = new Date(current);

    switch (unit) {
      case TimeUnit.Day:
        const end = new Date(current);
        end.setDate(end.getDate() + 1);
        return { start, end };

      case TimeUnit.Week:
        const weekStart = new Date(current);
        const weekEnd = new Date(current);
        // 月曜日を開始日とする
        const dayOfWeek = current.getDay();
        const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
        weekStart.setDate(current.getDate() - daysToMonday);
        weekEnd.setDate(weekStart.getDate() + 7);
        return { start: weekStart, end: weekEnd };

      case TimeUnit.Month:
        const monthStart = new Date(current.getFullYear(), current.getMonth(), 1);
        const monthEnd = new Date(current.getFullYear(), current.getMonth() + 1, 1);
        return { start: monthStart, end: monthEnd };

      case TimeUnit.Quarter:
        const quarter = Math.floor(current.getMonth() / 3);
        const quarterStart = new Date(current.getFullYear(), quarter * 3, 1);
        const quarterEnd = new Date(current.getFullYear(), (quarter + 1) * 3, 1);
        return { start: quarterStart, end: quarterEnd };

      default:
        return null;
    }
  }

  private getTimeLabel(start: Date, end: Date, unit: TimeUnit): string {
    const dayLabel = this.translate.instant('plans.gantt.labels.day');
    const monthLabel = this.translate.instant('plans.gantt.labels.month');
    const weekLabel = this.translate.instant('plans.gantt.labels.week');
    const quarterLabel = this.translate.instant('plans.gantt.labels.quarter');
    
    switch (unit) {
      case TimeUnit.Day:
        return `${start.getDate()}${dayLabel}`;
      case TimeUnit.Week:
        return `${start.getMonth() + 1}/${start.getDate()}`;
      case TimeUnit.Month:
        return `${start.getMonth() + 1}${monthLabel}`;
      case TimeUnit.Quarter:
        return `${quarterLabel}${Math.floor(start.getMonth() / 3) + 1}`;
      default:
        return `${start.getMonth() + 1}${monthLabel}`;
    }
  }

  private shouldShowYear(start: Date, end: Date, unit: TimeUnit, isFirst: boolean): boolean {
    if (isFirst) return true;

    switch (unit) {
      case TimeUnit.Day:
        return start.getMonth() === 0 && start.getDate() === 1;
      case TimeUnit.Week:
        return start.getMonth() === 0 && this.getWeekNumber(start) === 1;
      case TimeUnit.Month:
        return start.getMonth() === 0;
      case TimeUnit.Quarter:
        return start.getMonth() === 0;
      default:
        return start.getMonth() === 0;
    }
  }

  private getWeekNumber(date: Date): number {
    const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
    const pastDaysOfYear = (date.getTime() - firstDayOfYear.getTime()) / 86400000;
    return Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
  }

  getBarParams(cultivation: CultivationData) {
    if (!this.data) return null;
    const planStart = new Date(this.data.data.planning_start_date);
    const planEnd = new Date(this.data.data.planning_end_date);
    const start = new Date(cultivation.start_date);
    const end = new Date(cultivation.completion_date);
    
    const totalDays = this.daysBetween(planStart, planEnd);
    const chartWidth = this.config.width - this.config.margin.left - this.config.margin.right;

    const daysFromStart = this.daysBetween(planStart, start);
    const duration = this.daysBetween(start, end) + 1;

    const x = this.config.margin.left + (daysFromStart / totalDays) * chartWidth;
    const width = (duration / totalDays) * chartWidth;

    return { x, width };
  }

  private daysBetween(d1: Date, d2: Date): number {
    return Math.floor((d2.getTime() - d1.getTime()) / (1000 * 60 * 60 * 24));
  }

  private getTotalMonths(start: Date, end: Date): number {
    return (end.getFullYear() - start.getFullYear()) * 12 + (end.getMonth() - start.getMonth()) + 1;
  }

  private getTotalDays(start: Date, end: Date): number {
    return Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
  }

  private determineTimeScale(start: Date, end: Date, chartWidth: number): TimeScale {
    const totalDays = this.getTotalDays(start, end);
    
    // 日単位: 1日あたり2px以上、かつ総日数×2pxが利用可能幅以下
    const minPixelsPerDay = 2;
    if (totalDays * minPixelsPerDay <= chartWidth) {
      const minLabelWidth = 50;
      const interval = Math.max(1, Math.ceil((totalDays * minLabelWidth) / chartWidth));
      return { unit: TimeUnit.Day, label: '日', interval };
    }
    
    // 週単位: 1週間あたり14px以上、かつ総週数×14pxが利用可能幅以下
    const totalWeeks = Math.ceil(totalDays / 7);
    const minPixelsPerWeek = 14;
    if (totalWeeks * minPixelsPerWeek <= chartWidth) {
      const minLabelWidth = 50;
      const interval = Math.max(1, Math.ceil((totalWeeks * minLabelWidth) / chartWidth));
      return { unit: TimeUnit.Week, label: '週', interval };
    }
    
    // 月単位: 1ヶ月あたり30px以上、かつ総月数×30pxが利用可能幅以下
    const totalMonths = this.getTotalMonths(start, end);
    const minPixelsPerMonth = 30;
    if (totalMonths * minPixelsPerMonth <= chartWidth) {
      const minLabelWidth = 60;
      const interval = Math.max(1, Math.ceil((totalMonths * minLabelWidth) / chartWidth));
      return { unit: TimeUnit.Month, label: '月', interval };
    }
    
    // 四半期単位: フォールバック
    const totalQuarters = Math.ceil(totalMonths / 3);
    const minLabelWidth = 80;
    const interval = Math.max(1, Math.ceil((totalQuarters * minLabelWidth) / chartWidth));
    return { unit: TimeUnit.Quarter, label: 'Q', interval };
  }

  getCropColor(name: string): string {
    const colors = ['#9ae6b4', '#fbd38d', '#90cdf4', '#c6f6d5', '#feebc8', '#feb2b2'];
    const hash = name.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    return colors[hash % colors.length];
  }

  getCropStrokeColor(name: string): string {
    const colors = ['#48bb78', '#f6ad55', '#4299e1', '#2f855a', '#dd6b20', '#fc8181'];
    const hash = name.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    return colors[hash % colors.length];
  }

  onMouseDown(event: MouseEvent, cultivation: CultivationData) {
    if (event.button !== 0) return;
    event.preventDefault();

    // ドラッグの準備（まだドラッグは開始していない）
    this.isDragging = false;
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
      this.dragStartDisplayStartDate = new Date(this.data.data.planning_start_date);
      this.dragStartDisplayEndDate = new Date(this.data.data.planning_end_date);
    }

    // 現在のフィールドインデックスを保存
    this.originalFieldIndex = this.fieldGroups.findIndex(g => g.fieldName === cultivation.field_name);
    this.lastTargetFieldIndex = -1;

    this.globalMouseMoveHandler = (e: MouseEvent) => this.onMouseMove(e);
    this.globalMouseUpHandler = (e: MouseEvent) => this.onMouseUp(e);

    document.addEventListener('mousemove', this.globalMouseMoveHandler);
    document.addEventListener('mouseup', this.globalMouseUpHandler);
  }

  private onMouseMove(event: MouseEvent) {
    if (!this.draggedCultivation) return;

    const mouseDeltaX = event.clientX - this.dragStartX;
    const mouseDeltaY = event.clientY - this.dragStartY;

    // ドラッグ開始判定（まだ開始していない場合）
    if (!this.isDragging) {
      const distance = Math.sqrt(mouseDeltaX * mouseDeltaX + mouseDeltaY * mouseDeltaY);
      if (distance > this.dragThreshold) {
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
    const fieldIndexChange = Math.round(deltaY / ROW_HEIGHT);
    const targetFieldIndex = Math.max(0, Math.min(
      this.originalFieldIndex + fieldIndexChange,
      this.fieldGroups.length - 1
    ));

    // ハイライトの更新（圃場が変わった場合のみ）
    if (targetFieldIndex !== this.lastTargetFieldIndex && this.highlightRect) {
      const HEADER_HEIGHT = this.config.margin.top;
      const highlightY = HEADER_HEIGHT + (targetFieldIndex * ROW_HEIGHT);

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

  private onMouseUp(event: MouseEvent) {
    if (!this.draggedCultivation) return;

    // ハイライトを非表示
    if (this.highlightRect) {
      this.highlightRect.nativeElement.setAttribute('opacity', '0');
    }

    const cultivationId = this.draggedCultivation.id;
    const originalFieldName = this.draggedCultivation.field_name;

    // 現在の位置から新しい日付を計算
    const ROW_HEIGHT = this.config.rowHeight;
    const MARGIN_LEFT = this.config.margin.left;

    let newX = 0;
    let newFieldIndex = this.originalFieldIndex;
    let newFieldName = originalFieldName;
    let daysFromStart = 0;
    let newStartDate: Date | null = null;

    if (this.cachedBarBg) {
      // 現在のSVG座標から計算
      newX = parseFloat(this.cachedBarBg.getAttribute('x') || '0');
      const currentY = parseFloat(this.cachedBarBg.getAttribute('y') || '0');

      // 日付計算（ドラッグ開始時に保存された表示範囲を使用）
      const effectiveDisplayStartDate = this.dragStartDisplayStartDate || 
        (this.data ? new Date(this.data.data.planning_start_date) : new Date());
      const effectiveDisplayEndDate = this.dragStartDisplayEndDate || 
        (this.data ? new Date(this.data.data.planning_end_date) : new Date());
      const totalDays = this.daysBetween(effectiveDisplayStartDate, effectiveDisplayEndDate);
      const chartWidth = this.config.width - MARGIN_LEFT - this.config.margin.right;
      daysFromStart = Math.round((newX - MARGIN_LEFT) / chartWidth * totalDays);
      newStartDate = new Date(effectiveDisplayStartDate);
      newStartDate.setDate(newStartDate.getDate() + daysFromStart);

      // 圃場計算（Rails実装に合わせて、data-original-y属性から取得）
      const originalBarY = parseFloat(this.cachedBarBg.getAttribute('data-original-y') || '0');
      const deltaY = currentY - originalBarY;
      const fieldIndexChange = Math.round(deltaY / ROW_HEIGHT);
      newFieldIndex = Math.max(0, Math.min(
        this.originalFieldIndex + fieldIndexChange,
        this.fieldGroups.length - 1
      ));

      // 配列の範囲チェック
      if (newFieldIndex >= 0 && newFieldIndex < this.fieldGroups.length) {
        newFieldName = this.fieldGroups[newFieldIndex].fieldName;
      } else {
        newFieldName = originalFieldName; // フォールバック
        newFieldIndex = this.originalFieldIndex;
      }
    } else {
      // フォールバック
      newX = this.originalBarX;
      newFieldIndex = this.originalFieldIndex;
      newFieldName = originalFieldName;
      const effectiveDisplayStartDate = this.dragStartDisplayStartDate || 
        (this.data ? new Date(this.data.data.planning_start_date) : new Date());
      const effectiveDisplayEndDate = this.dragStartDisplayEndDate || 
        (this.data ? new Date(this.data.data.planning_end_date) : new Date());
      const totalDays = this.daysBetween(effectiveDisplayStartDate, effectiveDisplayEndDate);
      const chartWidth = this.config.width - MARGIN_LEFT - this.config.margin.right;
      daysFromStart = Math.round((newX - MARGIN_LEFT) / chartWidth * totalDays);
      newStartDate = new Date(effectiveDisplayStartDate);
      newStartDate.setDate(newStartDate.getDate() + daysFromStart);
    }

    // 実際にドラッグが行われた場合のみ処理
    if (this.isDragging) {
      // 有意な移動があった場合のみAPI呼び出し
      // - 圃場が変わった、または
      // - 2日以上の日付移動があった
      if (originalFieldName !== newFieldName || Math.abs(daysFromStart) > 2) {
        console.log('📍 ドラッグ完了（最適化実行）:', {
          cultivation_id: cultivationId,
          from_field: originalFieldName,
          to_field: newFieldName,
          new_start_date: newStartDate?.toISOString().split('T')[0],
          daysFromStart: daysFromStart
        });

        if (newStartDate && this.data) {
          // 楽観的更新を先に実行
          this.applyMovesLocally(cultivationId, newFieldName, newFieldIndex, newStartDate);

          // ドロップ後、最適化完了までスクリーンロックを表示
          this.showOptimizationLock = true;
          this.scheduleDetectChanges();
          // API呼び出し
          this.adjustCultivation(cultivationId, newFieldName, newFieldIndex, newStartDate);
        }
      } else {
        console.log('ℹ️ ドラッグされたが移動量が小さいため最適化スキップ');
        // 位置をリセット
        this.resetBarPosition();
      }
    } else {
      console.log('ℹ️ クリック操作のため最適化スキップ');
      // 位置をリセット
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
    this.removeGlobalListeners();
  }

  private removeGlobalListeners() {
    if (this.globalMouseMoveHandler) {
      document.removeEventListener('mousemove', this.globalMouseMoveHandler);
      this.globalMouseMoveHandler = null;
    }
    if (this.globalMouseUpHandler) {
      document.removeEventListener('mouseup', this.globalMouseUpHandler);
      this.globalMouseUpHandler = null;
    }
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

  private applyMovesLocally(cultivationId: number, newFieldName: string, newFieldIndex: number, newStartDate: Date) {
    if (!this.data) return;

    const cultivation = this.data.data.cultivations.find(c => c.id === cultivationId);
    if (!cultivation) return;

    // 期間を維持して終了日を計算
    const oldStartDate = new Date(cultivation.start_date);
    const oldEndDate = new Date(cultivation.completion_date);
    const duration = this.daysBetween(oldStartDate, oldEndDate);

    const newEndDate = new Date(newStartDate);
    newEndDate.setDate(newEndDate.getDate() + duration);

    // 楽観的更新: ローカルデータを更新
    cultivation.start_date = newStartDate.toISOString().split('T')[0];
    cultivation.completion_date = newEndDate.toISOString().split('T')[0];
    cultivation.field_name = newFieldName;
    cultivation.field_id = this.fieldGroups[newFieldIndex].fieldId;

    // fieldGroupsを再構築（圃場が変わった場合のため）
    this.updateChart();
  }

  debugData(): string {
    if (!this.data) return 'data: null';
    if (!this.data.data) return 'data.data: null';
    return `fields: ${this.data.data.fields?.length || 0}, cultivations: ${this.data.data.cultivations?.length || 0}`;
  }

  private adjustCultivation(cultivationId: number, newFieldName: string, newFieldIndex: number, newStartDate: Date) {
    if (!this.data) return;

    const planId = this.data.data.id;
    const targetField = this.fieldGroups[newFieldIndex];
    if (!targetField) return;

    // planTypeに応じて適切なエンドポイントを選択
    const isPublicPlan = this.planType === 'public';
    const endpoint = isPublicPlan
      ? `/api/v1/public_plans/cultivation_plans/${planId}/adjust`
      : `/api/v1/plans/cultivation_plans/${planId}/adjust`;

    const moves = [{
      allocation_id: cultivationId,
      action: 'move',
      to_field_id: targetField.fieldId,
      to_start_date: newStartDate.toISOString().split('T')[0]
    }];

    this.planService.adjustPlan(endpoint, { moves }).subscribe({
      next: (response) => {
        if (response.success) {
          console.log('✅ 調整が完了しました:', response);
          // サーバーからの最新データで更新
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
                  console.error('❌ データ再取得に失敗しました: フィールドデータがありません', data);
                  this.updateChart();
                }
                clearLockAndUpdate();
              },
              error: (error) => {
                console.error('❌ データ再取得APIエラー:', error);
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
                  console.error('❌ データ再取得に失敗しました: フィールドデータがありません', data);
                  this.updateChart();
                }
                clearLockAndUpdate();
              },
              error: (error) => {
                console.error('❌ データ再取得APIエラー:', error);
                this.updateChart();
                clearLockAndUpdate();
              }
            });
          }
        } else {
          console.error('❌ 調整に失敗しました:', response.message);
          this.handleAdjustmentFailure(response.message);
        }
      },
      error: (error: HttpErrorResponse) => {
        console.error('❌ API呼び出しエラー:', error);
        this.handleAdjustmentFailure(this.extractHttpErrorMessage(error));
      }
    });
  }
}
