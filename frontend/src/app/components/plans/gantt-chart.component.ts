import { Component, Input, OnChanges, OnInit, SimpleChanges, ElementRef, ViewChild, AfterViewInit, OnDestroy, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { CultivationPlanData, CultivationData } from '../../domain/plans/cultivation-plan-data';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { PlanService } from '../../services/plans/plan.service';

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

@Component({
  selector: 'app-gantt-chart',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <div class="gantt-container" #container>
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
              <text [attr.x]="month.x + (month.width / 2)" y="30" class="month-label" text-anchor="middle" font-size="13" font-weight="600" fill="#1F2937">
                {{ month.label }}
              </text>
              @if (month.showYear) {
                <text [attr.x]="month.x + (month.width / 2)" y="15" class="year-label" text-anchor="middle" font-size="12" font-weight="bold" fill="#6B7280">
                  {{ month.year }}年
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
    </div>
  `,
  styleUrl: './gantt-chart.component.css'
})
export class GanttChartComponent implements OnInit, OnChanges, AfterViewInit, OnDestroy {
  @Input() data: CultivationPlanData | null = null;

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
  private planService = inject(PlanService);

  constructor(private translate: TranslateService) {}

  ngOnInit(): void {
    if (this.data) {
      this.updateChart();
    }
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['data'] && this.data) {
      this.updateChart();
    }
  }

  ngAfterViewInit(): void {
    setTimeout(() => this.updateDimensions(), 0);
    window.addEventListener('resize', this.onResize);
  }

  ngOnDestroy(): void {
    window.removeEventListener('resize', this.onResize);
    this.removeGlobalListeners();
  }

  private onResize = () => {
    this.updateDimensions();
  };

  private updateDimensions() {
    if (this.container) {
      const width = this.container.nativeElement.getBoundingClientRect().width;
      this.config.width = Math.max(width, 800);
      if (this.data) {
        this.updateChart();
      }
    }
  }

  private updateChart() {
    if (!this.data) return;

    const fields = this.data.data.fields;
    const cultivations = this.data.data.cultivations;

    this.fieldGroups = fields.map(f => ({
      fieldName: f.name,
      fieldId: f.id,
      cultivations: cultivations.filter(c => c.field_id === f.id)
    }));

    this.config.height = this.config.margin.top + (this.fieldGroups.length * this.config.rowHeight) + this.config.margin.bottom;
    this.calculateMonths();
  }

  private calculateMonths() {
    if (!this.data) return;
    const start = new Date(this.data.data.planning_start_date);
    const end = new Date(this.data.data.planning_end_date);
    const totalDays = this.daysBetween(start, end);
    const chartWidth = this.config.width - this.config.margin.left - this.config.margin.right;

    this.months = [];
    let current = new Date(start);
    let x = this.config.margin.left;

    while (current <= end) {
      const year = current.getFullYear();
      const month = current.getMonth() + 1;
      const dInMonth = new Date(year, month, 0).getDate();
      const width = (dInMonth / totalDays) * chartWidth;

      this.months.push({
        date: new Date(current),
        year,
        month,
        label: `${month}月`,
        showYear: month === 1 || this.months.length === 0,
        x,
        width
      });

      x += width;
      current.setMonth(current.getMonth() + 1);
    }
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
    if (!this.draggedCultivation || !this.data) return;

    // エラー時はサーバーから最新データを再取得してロールバック
    const planId = this.data.data.id;
    const isPublicPlan = window.location.pathname.includes('/public-plans');
    
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

  private adjustCultivation(cultivationId: number, newFieldName: string, newFieldIndex: number, newStartDate: Date) {
    if (!this.data) return;

    const planId = this.data.data.id;
    const targetField = this.fieldGroups[newFieldIndex];
    if (!targetField) return;

    // planTypeの判定（URLから判定するか、Inputで受け取る）
    // 暫定的にpublic_plansを使用（後で改善可能）
    const isPublicPlan = window.location.pathname.includes('/public-plans');
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
        } else {
          console.error('❌ 調整に失敗しました:', response.message);
          // エラー時は楽観的更新をロールバック
          this.resetBarPosition();
        }
      },
      error: (error) => {
        console.error('❌ API呼び出しエラー:', error);
        // エラー時は楽観的更新をロールバック
        this.resetBarPosition();
      }
    });
  }
}
