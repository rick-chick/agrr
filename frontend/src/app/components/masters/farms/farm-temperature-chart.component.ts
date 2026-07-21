import {
  AfterViewChecked,
  ChangeDetectorRef,
  Component,
  Input,
  OnChanges,
  OnDestroy,
  OnInit,
  SimpleChanges,
  ViewChild,
  ElementRef
} from '@angular/core';
import { CommonModule } from '@angular/common';
import Chart from 'chart.js/auto';
import type { ChartConfiguration, ChartDataset } from 'chart.js';
import 'chartjs-adapter-date-fns';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { Subscription } from 'rxjs';
import {
  FarmTemperatureChartPeriod,
  FarmTemperatureChartPoint
} from '../../../domain/farms/farm-temperature-chart';
import { LoadFarmTemperatureChartUseCase } from '../../../usecase/farms/load-farm-temperature-chart.usecase';
import { LoadFarmTemperatureChartInputDto } from '../../../usecase/farms/load-farm-temperature-chart.dtos';
import {
  FarmTemperatureChartPresenter,
  FARM_TEMPERATURE_CHART_PROVIDERS
} from '../../../usecase/farms/farm-temperature-chart.providers';
import { FarmTemperatureChartView, FarmTemperatureChartViewState } from './farm-temperature-chart.view';

const INITIAL_STATE: FarmTemperatureChartViewState = {
  loading: false,
  error: null,
  chartData: null,
  notReady: false
};

const PERIOD_OPTIONS: readonly FarmTemperatureChartPeriod[] = ['30d', '90d', '180d', '365d'];

const TEMP_MIN_COLOR = '#0ea5e9';
const TEMP_MEAN_COLOR = '#2563eb';
const TEMP_MAX_COLOR = '#16a34a';

const PERIOD_LABEL_KEYS: Record<FarmTemperatureChartPeriod, string> = {
  '30d': 'farms.weather_section.period_30',
  '90d': 'farms.weather_section.period_90',
  '180d': 'farms.weather_section.period_180',
  '365d': 'farms.weather_section.period_365'
};

@Component({
  selector: 'app-farm-temperature-chart',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  providers: [...FARM_TEMPERATURE_CHART_PROVIDERS],
  template: `
    <section class="section-card farm-temperature-chart" aria-labelledby="farm-temperature-chart-heading">
      <h2 id="farm-temperature-chart-heading" class="section-title">
        {{ 'farms.weather_section.temperature_chart_title' | translate }}
      </h2>

      @if (weatherDataStatus !== 'completed' || control.notReady) {
        @if (weatherDataStatus === 'fetching') {
          <p class="farm-temperature-chart__status">
            {{
              'farms.weather_section.fetching_progress'
                | translate: { progress: weatherDataProgress }
            }}
          </p>
          <progress
            class="progress-bar farm-temperature-chart__progress"
            [value]="weatherDataProgress"
            max="100"
          ></progress>
        } @else if (weatherDataStatus === 'failed') {
          <p class="farm-temperature-chart__status">
            {{ 'farms.weather_section.fetch_failed' | translate }}
          </p>
        } @else {
          <p class="farm-temperature-chart__status">
            {{ 'farms.weather_section.preparing' | translate }}
          </p>
        }
      } @else {
        <p class="farm-temperature-chart__subtitle">
          {{
            'farms.weather_section.observed_subtitle'
              | translate: { period: (periodLabelKey | translate) }
          }}
        </p>

        <div class="farm-temperature-chart__period" role="group" [attr.aria-label]="'farms.weather_section.period_select' | translate">
          @for (option of periodOptions; track option) {
            <button
              type="button"
              class="farm-temperature-chart__period-btn"
              [class.farm-temperature-chart__period-btn--active]="selectedPeriod === option"
              (click)="selectPeriod(option)"
            >
              {{ periodLabelKeys[option] | translate }}
            </button>
          }
        </div>

        @if (control.loading) {
          <p class="farm-temperature-chart__status">
            {{ 'farms.weather_section.chart_loading' | translate }}
          </p>
        } @else if (control.error) {
          <p class="farm-temperature-chart__error">{{ control.error | translate }}</p>
          <button type="button" class="btn btn-secondary farm-temperature-chart__retry" (click)="retry()">
            {{ 'farms.weather_section.retry_load' | translate }}
          </button>
        } @else if (control.chartData) {
          <div class="farm-temperature-chart__chart-wrap">
            <canvas #temperatureCanvas></canvas>
          </div>
          @if (control.chartData.data_quality.missing_days > 0) {
            <p class="farm-temperature-chart__gap-notice">
              {{
                'farms.weather_section.data_gap_notice'
                  | translate: { count: control.chartData.data_quality.missing_days }
              }}
            </p>
          }
          <p class="farm-temperature-chart__hint">
            {{ 'farms.weather_section.plan_chart_hint' | translate }}
          </p>
        }
      }
    </section>
  `,
  styleUrls: ['./farm-temperature-chart.component.css']
})
export class FarmTemperatureChartComponent
  implements FarmTemperatureChartView, OnInit, OnChanges, AfterViewChecked, OnDestroy
{
  @Input({ required: true }) farmId!: number;
  @Input() weatherDataStatus: 'pending' | 'fetching' | 'completed' | 'failed' | undefined;
  @Input() weatherDataProgress = 0;

  @ViewChild('temperatureCanvas') temperatureCanvas?: ElementRef<HTMLCanvasElement>;

  readonly periodOptions = PERIOD_OPTIONS;
  readonly periodLabelKeys = PERIOD_LABEL_KEYS;

  selectedPeriod: FarmTemperatureChartPeriod = '90d';
  private temperatureChart: Chart<'line'> | null = null;
  private chartRefreshScheduled = false;
  private langChangeSub: Subscription | null = null;

  constructor(
    private readonly presenter: FarmTemperatureChartPresenter,
    private readonly useCase: LoadFarmTemperatureChartUseCase,
    private readonly cdr: ChangeDetectorRef,
    private readonly translate: TranslateService
  ) {}

  private _control: FarmTemperatureChartViewState = INITIAL_STATE;
  get control(): FarmTemperatureChartViewState {
    return this._control;
  }
  set control(value: FarmTemperatureChartViewState) {
    this._control = value;
    this.cdr.markForCheck();
    if (value.chartData) {
      this.scheduleChartRefresh();
    }
  }

  get periodLabelKey(): string {
    return PERIOD_LABEL_KEYS[this.selectedPeriod];
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.langChangeSub = this.translate.onLangChange.subscribe(() => {
      if (this.control.chartData) {
        this.scheduleChartRefresh();
      }
    });
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['weatherDataStatus'] && this.weatherDataStatus === 'completed') {
      this.tryLoadChart();
    }
    if (changes['farmId'] && !changes['farmId'].firstChange) {
      this.tryLoadChart();
    }
  }

  ngAfterViewChecked(): void {
    if (this.weatherDataStatus === 'completed' && this.control.chartData && !this.control.loading) {
      this.scheduleChartRefresh();
    }
  }

  ngOnDestroy(): void {
    this.langChangeSub?.unsubscribe();
    this.destroyChart();
  }

  selectPeriod(period: FarmTemperatureChartPeriod): void {
    if (this.selectedPeriod === period) return;
    this.selectedPeriod = period;
    this.loadChart();
  }

  retry(): void {
    this.loadChart();
  }

  private tryLoadChart(): void {
    if (this.weatherDataStatus !== 'completed' || !this.farmId) return;
    this.loadChart();
  }

  private loadChart(): void {
    const payload: LoadFarmTemperatureChartInputDto = {
      farmId: this.farmId,
      period: this.selectedPeriod
    };
    this.destroyChart();
    this.control = { loading: true, error: null, chartData: null, notReady: false };
    this.useCase.execute(payload);
  }

  private scheduleChartRefresh(): void {
    if (this.chartRefreshScheduled) return;
    this.chartRefreshScheduled = true;

    Promise.resolve().then(() => {
      this.chartRefreshScheduled = false;
      this.initializeChart();
      this.updateChart();
    });
  }

  private initializeChart(): void {
    if (!this.temperatureCanvas || this.temperatureChart) return;

    this.temperatureChart = new Chart(this.temperatureCanvas.nativeElement, {
      type: 'line',
      data: { labels: [], datasets: [] },
      options: this.buildChartOptions()
    });
  }

  private updateChart(): void {
    if (!this.temperatureChart || !this.control.chartData) return;

    const points = this.control.chartData.points;
    if (points.length === 0) {
      this.temperatureChart.data.labels = [];
      this.temperatureChart.data.datasets = [];
      this.temperatureChart.update();
      return;
    }

    const labels = points.map((point) => point.date);
    this.temperatureChart.data.labels = labels;
    this.temperatureChart.data.datasets = [
      this.buildTemperatureDataset(
        this.chartLabel('chart_temp_max'),
        points,
        'temperature_max',
        TEMP_MAX_COLOR
      ),
      this.buildTemperatureDataset(
        this.chartLabel('chart_temp_mean'),
        points,
        'temperature_mean',
        TEMP_MEAN_COLOR
      ),
      this.buildTemperatureDataset(
        this.chartLabel('chart_temp_min'),
        points,
        'temperature_min',
        TEMP_MIN_COLOR
      )
    ];
    this.temperatureChart.update();
  }

  private buildTemperatureDataset(
    label: string,
    data: FarmTemperatureChartPoint[],
    key: 'temperature_min' | 'temperature_mean' | 'temperature_max',
    color: string
  ): ChartDataset<'line'> {
    return {
      label,
      data: data.map((entry) => entry[key] ?? null),
      borderColor: color,
      backgroundColor: this.hexToRgba(color, 0.2),
      borderWidth: 2,
      tension: 0.3,
      pointRadius: 0,
      pointHoverRadius: 0,
      spanGaps: false,
      fill: false
    };
  }

  private buildChartOptions(): ChartConfiguration<'line'>['options'] {
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
            tooltipFormat: this.tooltipFormat(),
            displayFormats: {
              day: this.chartDateTickFormat()
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
            text: this.chartLabel('chart_temp_axis')
          },
          grid: {
            color: '#e5e7eb'
          }
        }
      }
    };
  }

  private chartLabel(key: string): string {
    return this.translate.instant(`farms.weather_section.${key}`);
  }

  private tooltipFormat(): string {
    return this.translate.instant('plans.field_climate.chart.tooltip_format');
  }

  private chartDateTickFormat(): string {
    switch (this.translate.currentLang) {
      case 'in':
        return 'dd/MM';
      case 'ja':
        return 'MM/dd';
      default:
        return 'MM/dd';
    }
  }

  private hexToRgba(hex: string, alpha: number): string {
    const normalized = hex.replace('#', '');
    const r = Number.parseInt(normalized.slice(0, 2), 16);
    const g = Number.parseInt(normalized.slice(2, 4), 16);
    const b = Number.parseInt(normalized.slice(4, 6), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }

  private destroyChart(): void {
    this.temperatureChart?.destroy();
    this.temperatureChart = null;
  }
}
