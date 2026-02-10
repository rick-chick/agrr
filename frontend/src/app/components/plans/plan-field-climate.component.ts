import {
  AfterViewChecked,
  AfterViewInit,
  ChangeDetectorRef,
  Component,
  ElementRef,
  EventEmitter,
  Input,
  OnChanges,
  OnDestroy,
  OnInit,
  Output,
  SimpleChanges,
  ViewChild
} from '@angular/core';
import { CommonModule } from '@angular/common';
import Chart from 'chart.js/auto';
import type { ChartConfiguration, ChartDataset, Plugin } from 'chart.js';
import 'chartjs-adapter-date-fns';
import { TranslateService } from '@ngx-translate/core';
import {
  ClimateGddPoint,
  ClimateTemperaturePoint,
  StageRequirement
} from '../../domain/plans/field-cultivation-climate-data';
import { PlanFieldClimateView, PlanFieldClimateViewState } from './plan-field-climate.view';
import { LoadFieldClimateUseCase } from '../../usecase/plans/field-climate/load-field-climate.usecase';
import { LoadFieldClimateInputDto } from '../../usecase/plans/field-climate/load-field-climate.dtos';
import { PlanFieldClimatePresenter } from '../../adapters/plans/plan-field-climate.presenter';
import { FieldClimateApiGateway } from '../../adapters/plans/field-climate-api.gateway';
import { FIELD_CLIMATE_GATEWAY } from '../../usecase/plans/field-climate/field-climate.gateway';
import { LOAD_FIELD_CLIMATE_OUTPUT_PORT } from '../../usecase/plans/field-climate/load-field-climate.output-port';

const INITIAL_STATE: PlanFieldClimateViewState = {
  loading: false,
  error: null,
  climateData: null
};

type StageTemperatureBand = {
  stageName: string;
  startValue: number;
  endValue: number;
  optimalMin: number;
  optimalMax: number;
  highThreshold?: number | null;
  lowThreshold?: number | null;
  optimalColor: string;
  stressColor: string;
};

@Component({
  selector: 'app-plan-field-climate',
  standalone: true,
  imports: [CommonModule],
  providers: [
    PlanFieldClimatePresenter,
    LoadFieldClimateUseCase,
    FieldClimateApiGateway,
    { provide: LOAD_FIELD_CLIMATE_OUTPUT_PORT, useExisting: PlanFieldClimatePresenter },
    { provide: FIELD_CLIMATE_GATEWAY, useExisting: FieldClimateApiGateway }
  ],
  template: `
    <section class="plan-field-climate">
      <header class="plan-field-climate__header">
        <div class="plan-field-climate__header-info">
          <p class="plan-field-climate__title">{{ headerTitle }}</p>
          <p class="plan-field-climate__subtitle">{{ headerSubtitle }}</p>
          <div class="plan-field-climate__header-meta">
            <span>{{ headerFieldName }}</span>
            <span>{{ headerPeriod }}</span>
          </div>
        </div>
        <button
          type="button"
          class="plan-field-climate__close"
          aria-label="Close climate chart"
          (click)="close.emit()"
        >
          ×
        </button>
      </header>

      <div *ngIf="control.loading" class="plan-field-climate__status">
        <p>Loading climate data…</p>
      </div>

      <div *ngIf="control.error" class="plan-field-climate__error">
        <p>{{ control.error }}</p>
        <button type="button" class="plan-field-climate__retry" (click)="retry()">Retry</button>
      </div>

      <section *ngIf="control.climateData" class="plan-field-climate__content">
        <dl class="plan-field-climate__stats">
          <div>
            <dt>Base temperature</dt>
            <dd>{{ control.climateData.crop_requirements.base_temperature }}℃</dd>
          </div>
          <div *ngIf="optimalRange">
            <dt>Optimal range</dt>
            <dd>{{ optimalRange }}</dd>
          </div>
          <div>
            <dt>Current stage</dt>
            <dd>{{ currentStage }}</dd>
          </div>
        </dl>

        <div class="plan-field-climate__stage-list">
          <article class="plan-field-climate__stage" *ngFor="let stage of stageRequirements">
            <p class="plan-field-climate__stage-name">{{ stage.name }}</p>
            <p class="plan-field-climate__stage-value">{{ stage.cumulative_gdd_required }} GDD</p>
          </article>
        </div>

        <div class="plan-field-climate__charts">
          <article class="plan-field-climate__chart-card">
            <header>
              <h4>Daily temperature</h4>
            </header>
            <div class="plan-field-climate__chart-wrapper">
              <canvas #temperatureCanvas></canvas>
            </div>
          </article>
          <article class="plan-field-climate__chart-card">
            <header>
              <h4>GDD progress</h4>
            </header>
            <div class="plan-field-climate__chart-wrapper">
              <canvas #gddCanvas></canvas>
            </div>
          </article>
        </div>
      </section>
    </section>
  `,
  styleUrls: ['./plan-field-climate.component.css']
})
export class PlanFieldClimateComponent
  implements
    PlanFieldClimateView,
    OnInit,
    OnChanges,
    AfterViewInit,
    AfterViewChecked,
    OnDestroy
{
  @Input() fieldCultivationId: number | null = null;
  @Input() planType: 'private' | 'public' = 'private';
  @Output() close = new EventEmitter<void>();

  @ViewChild('temperatureCanvas') temperatureCanvas?: ElementRef<HTMLCanvasElement>;
  @ViewChild('gddCanvas') gddCanvas?: ElementRef<HTMLCanvasElement>;

  private _control: PlanFieldClimateViewState = { ...INITIAL_STATE };

  private temperatureChart: Chart | null = null;
  private gddChart: Chart | null = null;
  private currentRequest: LoadFieldClimateInputDto | null = null;
  private viewReady = false;
  private chartRefreshScheduled = false;
  private stageBands: StageTemperatureBand[] = [];
  private readonly stageColorPalette = [
    { optimal: 'rgba(59, 130, 246, 0.16)', stress: 'rgba(239, 68, 68, 0.08)' },
    { optimal: 'rgba(16, 185, 129, 0.16)', stress: 'rgba(239, 68, 68, 0.08)' },
    { optimal: 'rgba(249, 115, 22, 0.16)', stress: 'rgba(239, 68, 68, 0.08)' },
    { optimal: 'rgba(168, 85, 247, 0.16)', stress: 'rgba(239, 68, 68, 0.08)' },
    { optimal: 'rgba(14, 165, 233, 0.16)', stress: 'rgba(239, 68, 68, 0.08)' }
  ];
  private lastFieldCultivationId: number | null = null;

  constructor(
    private readonly presenter: PlanFieldClimatePresenter,
    private readonly useCase: LoadFieldClimateUseCase,
    private readonly cdr: ChangeDetectorRef,
    private readonly translate: TranslateService
  ) {}

  ngOnInit(): void {
    this.presenter.setView(this);
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['fieldCultivationId'] || changes['planType']) {
      this.loadClimateIfNeeded();
    }
  }

  ngAfterViewInit(): void {
    this.viewReady = true;
    this.scheduleChartRefresh();
  }

  ngAfterViewChecked(): void {
    if (!this.viewReady || !this.control.climateData) return;
    if ((!this.temperatureChart && this.temperatureCanvas) || (!this.gddChart && this.gddCanvas)) {
      this.scheduleChartRefresh();
    }
  }

  ngOnDestroy(): void {
    this.temperatureChart?.destroy();
    this.gddChart?.destroy();
  }

  get control(): PlanFieldClimateViewState {
    return this._control;
  }

  set control(value: PlanFieldClimateViewState) {
    const newFieldId = value.climateData?.field_cultivation?.id ?? null;
    if (newFieldId !== this.lastFieldCultivationId) {
      this.resetChartsForNewField();
      this.lastFieldCultivationId = newFieldId;
    }
    this._control = value;
    this.cdr.markForCheck();
    this.scheduleChartRefresh();
  }

  get headerTitle(): string {
    return (
      this.control.climateData?.field_cultivation.crop_name ??
      'Field climate data'
    );
  }

  get headerSubtitle(): string {
    return this.control.climateData?.farm.name ?? 'Awaiting selection';
  }

  get headerFieldName(): string {
    return this.control.climateData?.field_cultivation.field_name ?? '—';
  }

  get headerPeriod(): string {
    const field = this.control.climateData?.field_cultivation;
    if (!field?.start_date || !field?.completion_date) return '—';
    return `${field.start_date} – ${field.completion_date}`;
  }

  get stageRequirements() {
    return this.control.climateData?.stages ?? [];
  }

  get currentStage(): string {
    const gddPoints = this.control.climateData?.gdd_data;
    const lastPoint = gddPoints?.[gddPoints.length - 1];
    return lastPoint?.current_stage ?? '—';
  }

  get optimalRange(): string | null {
    const range = this.control.climateData?.crop_requirements.optimal_temperature_range;
    if (!range) return null;
    return `${range.min}℃ – ${range.max}℃`;
  }

  retry(): void {
    if (!this.currentRequest) return;
    this.control = { loading: true, error: null, climateData: null };
    this.useCase.execute(this.currentRequest);
  }

  private loadClimateIfNeeded(): void {
    if (!this.fieldCultivationId) {
      this.currentRequest = null;
      this.control = { loading: false, error: null, climateData: null };
      return;
    }

    const payload: LoadFieldClimateInputDto = {
      fieldCultivationId: this.fieldCultivationId,
      planType: this.planType
    };

    const shouldFetch =
      !this.currentRequest ||
      this.currentRequest.fieldCultivationId !== payload.fieldCultivationId ||
      this.currentRequest.planType !== payload.planType;

    if (!shouldFetch) return;

    this.currentRequest = payload;
    this.control = { loading: true, error: null, climateData: null };
    this.useCase.execute(payload);
  }

  private initializeCharts(): void {
    if (!this.viewReady) return;

    if (this.temperatureCanvas && !this.temperatureChart) {
      this.temperatureChart = new Chart(this.temperatureCanvas.nativeElement, {
        type: 'line',
        data: { labels: [], datasets: [] },
        options: this.buildChartOptions(this.translate.instant('plans.field_climate.chart.temperature')),
        plugins: [this.getStageBandPlugin()]
      });
    }

    if (this.gddCanvas && !this.gddChart) {
      this.gddChart = new Chart(this.gddCanvas.nativeElement, {
        type: 'line',
        data: { labels: [], datasets: [] },
        options: this.buildGddChartOptions(this.translate.instant('plans.field_climate.chart.cumulative_gdd'))
      });
    }
  }

  private refreshCharts(): void {
    this.updateTemperatureChart();
    this.updateGddChart();
  }

  private scheduleChartRefresh(): void {
    if (this.chartRefreshScheduled) return;
    this.chartRefreshScheduled = true;

    Promise.resolve().then(() => {
      this.chartRefreshScheduled = false;
      this.initializeCharts();
      this.refreshCharts();
    });
  }

  private updateTemperatureChart(): void {
    if (!this.temperatureChart) return;
    const weather = this.control.climateData?.weather_data ?? [];
    if (weather.length === 0) {
      this.temperatureChart.data.labels = [];
      this.temperatureChart.data.datasets = [];
      this.temperatureChart.update();
      return;
    }

    this.stageBands = this.buildStageBands();

    const labels = weather.map(entry => entry.date);
    const datasets: ChartDataset<'line'>[] = [
      this.buildTemperatureDataset(this.translate.instant('plans.field_climate.chart.min_temp'), weather, 'temperature_min', '#0ea5e9'),
      this.buildTemperatureDataset(this.translate.instant('plans.field_climate.chart.mean_temp'), weather, 'temperature_mean', '#2563eb'),
      this.buildTemperatureDataset(this.translate.instant('plans.field_climate.chart.max_temp'), weather, 'temperature_max', '#16a34a')
    ];

    this.temperatureChart.data.labels = labels;
    this.temperatureChart.data.datasets = datasets;
    this.temperatureChart.update();
  }

  private updateGddChart(): void {
    if (!this.gddChart) return;
    const gddData = this.control.climateData?.gdd_data ?? [];
    if (gddData.length === 0) {
      this.gddChart.data.labels = [];
      this.gddChart.data.datasets = [];
      this.gddChart.update();
      return;
    }

    const labels = gddData.map(entry => entry.date);
    const stageRequirementDataset = this.buildStageRequirementDataset(
      labels,
      gddData
    );

    const datasets: ChartDataset<'line'>[] = [
      this.buildGddDataset(
        this.translate.instant('plans.field_climate.chart.daily_gdd'),
        gddData,
        entry => entry.gdd,
        '#f97316',
        'y2'
      ),
      this.buildGddDataset(
        this.translate.instant('plans.field_climate.chart.cumulative_gdd'),
        gddData,
        entry => entry.cumulative_gdd,
        '#10b981',
        'y1'
      )
    ];

    if (stageRequirementDataset) {
      datasets.push(stageRequirementDataset);
    }

    this.gddChart.data.labels = labels;
    this.gddChart.data.datasets = datasets;
    this.gddChart.update();
  }

  private buildTemperatureDataset(
    label: string,
    data: ClimateTemperaturePoint[],
    key: 'temperature_min' | 'temperature_mean' | 'temperature_max',
    color: string
  ): ChartDataset<'line'> {
    return {
      label,
      data: data.map(entry => entry[key] ?? null),
      borderColor: color,
      backgroundColor: this.hexToRgba(color, 0.2),
      borderWidth: 2,
      tension: 0.3,
      pointRadius: 0,
      pointHoverRadius: 0,
      spanGaps: true,
      fill: false
    };
  }

  private buildGddDataset(
    label: string,
    data: ClimateGddPoint[],
    valueExtractor: (entry: ClimateGddPoint) => number,
    color: string,
    axisId: 'y1' | 'y2' = 'y1'
  ): ChartDataset<'line'> {
    return {
      label,
      data: data.map(entry => valueExtractor(entry)),
      borderColor: color,
      backgroundColor: this.hexToRgba(color, 0.15),
      borderWidth: 2,
      tension: 0.25,
      pointRadius: 0,
      pointHoverRadius: 0,
      spanGaps: true,
      fill: false,
      yAxisID: axisId
    };
  }

  private buildConstantDataset(
    label: string,
    labels: string[],
    value: number,
    color: string
  ): ChartDataset<'line'> {
    return {
      label,
      data: labels.map(() => value),
      borderColor: color,
      backgroundColor: 'transparent',
      borderWidth: 1,
      borderDash: [6, 4],
      tension: 0.1,
      pointRadius: 0,
      pointHoverRadius: 0,
      spanGaps: true,
      fill: false,
      yAxisID: 'y1'
    };
  }

  private buildChartOptions(yLabel: string): ChartConfiguration<'line'>['options'] {
    return {
      responsive: true,
      maintainAspectRatio: false,
      layout: {
        padding: 8
      },
      plugins: {
        legend: {
          display: true,
          position: 'top'
        },
        tooltip: {
          mode: 'index',
          intersect: false
        }
      },
      elements: {
        point: {
          radius: 0,
          hoverRadius: 0
        }
      },
      scales: {
        x: {
          type: 'time',
          time: {
            unit: 'day',
            tooltipFormat: this.translate.instant('plans.field_climate.chart.tooltip_format'),
            displayFormats: {
              day: 'MM/dd'
            }
          },
          grid: {
            color: '#e5e7eb'
          },
          ticks: {
            maxRotation: 0,
            autoSkip: true
          }
        },
        y: {
          title: {
            display: true,
            text: yLabel
          },
          grid: {
            color: '#e5e7eb'
          }
        }
      }
    };
  }

  private buildGddChartOptions(
    yLabel: string
  ): ChartConfiguration<'line'>['options'] {
    return {
      responsive: true,
      maintainAspectRatio: false,
      layout: {
        padding: 8
      },
      plugins: {
        legend: {
          display: true,
          position: 'top'
        },
        tooltip: {
          mode: 'index',
          intersect: false
        }
      },
      scales: {
        x: {
          type: 'time',
          time: {
            unit: 'day',
            tooltipFormat: this.translate.instant('plans.field_climate.chart.tooltip_format'),
            displayFormats: {
              day: 'MM/dd'
            }
          },
          grid: {
            color: '#e5e7eb'
          },
          ticks: {
            maxRotation: 0,
            autoSkip: true
          }
        },
        y1: {
          type: 'linear',
          position: 'left',
          display: true,
          beginAtZero: true,
          min: 0,
          title: {
            display: true,
            text: yLabel,
            color: '#10b981'
          },
          ticks: {
            color: '#10b981'
          },
          grid: {
            color: '#e5e7eb'
          }
        },
        y2: {
          type: 'linear',
          position: 'right',
          display: true,
          beginAtZero: true,
          min: 0,
          title: {
            display: true,
            text: this.translate.instant('plans.field_climate.chart.daily_gdd'),
            color: '#f97316'
          },
          ticks: {
            color: '#f97316'
          },
          grid: {
            drawOnChartArea: false
          }
        }
      }
    };
  }

  private buildStageBands(): StageTemperatureBand[] {
    const climate = this.control.climateData;
    if (!climate) return [];
    const gddData = climate.gdd_data;
    if (!gddData.length) return [];
    if (!climate.stages || climate.stages.length === 0) return [];

    const palette = this.stageColorPalette;
    const fallbackStart =
      this.toTimestamp(climate.field_cultivation.start_date) ??
      this.toTimestamp(gddData[0]?.date) ??
      Date.now();
    const fallbackEnd =
      this.toTimestamp(climate.field_cultivation.completion_date) ??
      this.toTimestamp(gddData[gddData.length - 1]?.date) ??
      Date.now();

    const bands: StageTemperatureBand[] = [];
    for (let index = 0; index < climate.stages.length; index++) {
      const stage = climate.stages[index];
      const prevCumulative =
        index > 0 ? climate.stages[index - 1].cumulative_gdd_required : 0;
      const isLastStage = index === climate.stages.length - 1;

      const stageRecords = gddData.filter((entry) => {
        if (isLastStage) {
          return entry.cumulative_gdd > prevCumulative;
        }
        return (
          entry.cumulative_gdd >= prevCumulative &&
          entry.cumulative_gdd <= stage.cumulative_gdd_required
        );
      });

      const recordsToUse = stageRecords.length ? stageRecords : gddData;
      const startValue =
        recordsToUse.length > 0
          ? this.toTimestamp(recordsToUse[0].date) ?? fallbackStart
          : fallbackStart;
      const endValue =
        recordsToUse.length > 0
          ? this.toTimestamp(recordsToUse[recordsToUse.length - 1].date) ?? fallbackEnd
          : fallbackEnd;

      const color = palette[index % palette.length];
      const optimalMin =
        stage.optimal_temperature_min ??
        climate.crop_requirements.optimal_temperature_range?.min ??
        climate.crop_requirements.base_temperature;
      const optimalMax =
        stage.optimal_temperature_max ??
        climate.crop_requirements.optimal_temperature_range?.max ??
        climate.crop_requirements.base_temperature;

      bands.push({
        stageName: stage.name,
        startValue: startValue || fallbackStart,
        endValue: endValue || fallbackEnd,
        optimalMin,
        optimalMax,
        highThreshold: stage.high_stress_threshold,
        lowThreshold: stage.low_stress_threshold,
        optimalColor: color.optimal,
        stressColor: color.stress
      });
    }

    return bands;
  }

  private getStageBandPlugin(): Plugin<'line'> {
    return {
      id: 'stageBandPlugin',
      beforeDatasetsDraw: (chart) => {
        if (!this.stageBands.length) return;
        const ctx = chart.ctx;
        const xScale = chart.scales['x'];
        const yScale = chart.scales['y'];
        if (!xScale || !yScale) return;

        ctx.save();
        this.stageBands.forEach(band => {
          const startX = xScale.getPixelForValue(band.startValue);
          const endX = xScale.getPixelForValue(band.endValue);
          if (isNaN(startX) || isNaN(endX) || endX <= startX) return;

          const top = yScale.getPixelForValue(band.optimalMax);
          const bottom = yScale.getPixelForValue(band.optimalMin);
          if (isNaN(top) || isNaN(bottom)) return;
          const height = bottom - top;
          if (height <= 0) return;

          ctx.fillStyle = band.optimalColor;
          ctx.fillRect(startX, top, endX - startX, height);

          ctx.lineWidth = 1.5;
          ctx.strokeStyle = band.stressColor;
          ctx.setLineDash([5, 4]);
          if (band.highThreshold !== undefined && band.highThreshold !== null) {
            const highY = yScale.getPixelForValue(band.highThreshold);
            if (!isNaN(highY)) {
              ctx.beginPath();
              ctx.moveTo(startX, highY);
              ctx.lineTo(endX, highY);
              ctx.stroke();
            }
          }
          if (band.lowThreshold !== undefined && band.lowThreshold !== null) {
            const lowY = yScale.getPixelForValue(band.lowThreshold);
            if (!isNaN(lowY)) {
              ctx.beginPath();
              ctx.moveTo(startX, lowY);
              ctx.lineTo(endX, lowY);
              ctx.stroke();
            }
          }

          ctx.setLineDash([]);
          ctx.font = '12px sans-serif';
          ctx.fillStyle = 'rgba(255,255,255,0.95)';
          ctx.fillText(
            band.stageName,
            startX + 6,
            Math.min(top + 16, top + height - 8)
          );
        });
        ctx.restore();
      }
    };
  }

  private resetChartsForNewField(): void {
    this.stageBands = [];
    this.temperatureChart?.destroy();
    this.gddChart?.destroy();
    this.temperatureChart = null;
    this.gddChart = null;
  }

  private toTimestamp(value?: string | null): number | null {
    if (!value) return null;
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : parsed;
  }

  private inferStageNameFromCumulative(
    cumulative: number,
    orderedStages: StageRequirement[]
  ): string | null {
    for (const stage of orderedStages) {
      if (cumulative <= stage.cumulative_gdd_required) {
        return stage.name;
      }
    }

    return orderedStages.at(-1)?.name ?? null;
  }

  private buildStageRequirementDataset(
    labels: string[],
    gddData: ClimateGddPoint[]
  ): ChartDataset<'line'> | null {
    const stages = this.stageRequirements;
    if (stages.length === 0 || gddData.length === 0) {
      return null;
    }

    const data = gddData.map((entry) => {
      const cumulative = entry.cumulative_gdd ?? 0;
      return this.getStageRequirementForCumulative(cumulative, stages);
    });

    return {
      label: this.translate.instant('plans.field_climate.chart.required_cumulative_gdd'),
      data,
      stepped: 'before',
      borderColor: '#ef4444',
      backgroundColor: 'transparent',
      borderWidth: 1.5,
      borderDash: [6, 4],
      pointRadius: 0,
      pointHoverRadius: 0,
      spanGaps: true,
      fill: false,
      yAxisID: 'y1'
    };
  }

  private getStageRequirementForCumulative(
    cumulative: number,
    stages: StageRequirement[]
  ): number {
    for (const stage of stages) {
      if (cumulative <= stage.cumulative_gdd_required) {
        return stage.cumulative_gdd_required;
      }
    }

    return stages.at(-1)?.cumulative_gdd_required ?? 0;
  }

  private hexToRgba(hex: string, alpha: number): string {
    const stripped = hex.replace('#', '');
    const bigint = parseInt(stripped, 16);
    const r = (bigint >> 16) & 255;
    const g = (bigint >> 8) & 255;
    const b = bigint & 255;
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }
}
