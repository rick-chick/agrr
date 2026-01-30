import { Component, Input, OnChanges, OnInit, SimpleChanges, ElementRef, ViewChild, AfterViewInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { CultivationPlanData, CultivationData } from '../../domain/plans/cultivation-plan-data';
import { TranslateModule, TranslateService } from '@ngx-translate/core';

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
                     [attr.data-id]="cultivation.id">
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
  private globalMouseMoveHandler: any;
  private globalMouseUpHandler: any;

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

    this.isDragging = true;
    this.draggedCultivation = cultivation;
    this.dragStartX = event.clientX;
    this.dragStartY = event.clientY;

    this.globalMouseMoveHandler = (e: MouseEvent) => this.onMouseMove(e);
    this.globalMouseUpHandler = (e: MouseEvent) => this.onMouseUp(e);

    document.addEventListener('mousemove', this.globalMouseMoveHandler);
    document.addEventListener('mouseup', this.globalMouseUpHandler);
  }

  private onMouseMove(event: MouseEvent) {
    if (!this.isDragging || !this.draggedCultivation) return;
    // Implement visual feedback if needed
  }

  private onMouseUp(event: MouseEvent) {
    if (!this.isDragging) return;
    
    // Logic to calculate new date and field based on event.clientX/Y
    // and send update to backend.
    
    this.isDragging = false;
    this.draggedCultivation = null;
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
}
