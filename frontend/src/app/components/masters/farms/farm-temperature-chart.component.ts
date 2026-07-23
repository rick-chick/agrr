import {
  AfterViewInit,
  ChangeDetectorRef,
  Component,
  ElementRef,
  Input,
  OnChanges,
  OnDestroy,
  OnInit,
  SimpleChanges,
  ViewChild,
  inject
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import Chart from 'chart.js/auto';
import type { ChartConfiguration, ChartDataset } from 'chart.js';
import 'chartjs-adapter-date-fns';
import { Farm } from '../../../domain/farms/farm';
import {
  FarmTemperatureChartPeriod,
  FarmTemperatureChartPoint
} from '../../../domain/farms/farm-temperature-chart';
import { LoadFarmTemperatureChartUseCase } from '../../../usecase/farms/load-farm-temperature-chart.usecase';
import {
  FarmTemperatureChartPresenter,
  FARM_TEMPERATURE_CHART_PROVIDERS
} from '../../../usecase/farms/farm-temperature-chart.providers';
import { FarmTemperatureChartView, FarmTemperatureChartViewState } from './farm-temperature-chart.view';

const PERIODS: FarmTemperatureChartPeriod[] = ['30d', '90d', '180d', '365d'];

const INITIAL_STATE: FarmTemperatureChartViewState = {
  loading: false,
  error: null,
  chartData: null
};

@Component({
  selector: 'app-farm-temperature-chart',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  providers: [...FARM_TEMPERATURE_CHART_PROVIDERS],
  template: `
    <section class="farm-temperature-chart section-card" aria-labelledby="farm-temp-chart-heading">
      <h2 id="farm-temp-chart-heading" class="section-title">
        {{ 'farms.weather_section.temperature_chart_title' | translate }}
      </h2>

      @if (weatherStatus !== 'completed') {
        <p class="farm-temperature-chart__status">
          @if (weatherStatus === 'fetching' || weatherStatus === 'pending') {
            {{
              'farms.weather_section.fetching_progress'
                | translate: { progress: weatherProgress ?? 0 }
            }}
          } @else if (weatherStatus === 'failed') {
            {{ 'farms.weather_section.fetch_failed' | translate }}
          } @else {
            {{ 'farms.weather_section.preparing' | translate }}
          }
        </p>
      } @else {
        <p class="farm-temperature-chart__subtitle">
          {{ observedSubtitleKey | translate: { period: periodLabelKey | translate } }}
        </p>

        <div class="farm-temperature-chart__periods" role="group" [attr.aria-label]="'farms.weather_section.period_select' | translate">
          @for (option of periods; track option) {
            <button
              type="button"
              class="farm-temperature-chart__period-btn"
              [class.farm-temperature-chart__period-btn--active]="selectedPeriod === option"
              (click)="selectPeriod(option)"
            >
              {{ periodButtonKey(option) | translate }}
            </button>
          }
        </div>

        @if (control.loading) {
          <p class="farm-temperature-chart__status">
            {{ 'farms.weather_section.chart_loading' | translate }}
          </p>
        } @else if (control.error) {
          <p class="farm-temperature-chart__error">{{ control.error | translate }}</p>
          <button type="button" class="btn btn-secondary farm-temperature-chart__retry" (click)="reload()">
            {{ 'farms.weather_section.retry_load' | translate }}
          </button>
        } @else if (control.chartData) {
          <div class="farm-temperature-chart__canvas-wrap">
            <canvas #temperatureCanvas aria-hidden="true"></canvas>
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
  implements FarmTemperatureChartView, OnInit, OnChanges, AfterViewInit, OnDestroy
{
  @Input({ required: true }) farmId!: number;
  @Input() weatherStatus: Farm['weather_data_status'] | undefined;
  @Input() weatherProgress: number | undefined;

  readonly periods = PERIODS;
  selectedPeriod: FarmTemperatureChartPeriod = '90d';

  private readonly loadUseCase = inject(LoadFarmTemperatureChartUseCase);
  private readonly presenter = inject(FarmTemperatureChartPresenter);
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);

  @ViewChild('temperatureCanvas') temperatureCanvasRef?: ElementRef<HTMLCanvasElement>;

  private chart: Chart<'line'> | null = null;
  private viewReady = false;

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

  get observedSubtitleKey(): string {
    return 'farms.weather_section.observed_subtitle';
  }

  get periodLabelKey(): string {
    return this.periodButtonKey(this.selectedPeriod);
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.maybeLoadChart();
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['weatherStatus'] && this.weatherStatus === 'completed') {
      this.maybeLoadChart();
    }
  }

  ngAfterViewInit(): void {
    this.viewReady = true;
    if (this.control.chartData) {
      this.scheduleChartRefresh();
    }
  }

  ngOnDestroy(): void {
    this.chart?.destroy();
    this.chart = null;
  }

  periodButtonKey(period: FarmTemperatureChartPeriod): string {
    switch (period) {
      case '30d':
        return 'farms.weather_section.period_30';
      case '90d':
        return 'farms.weather_section.period_90';
      case '180d':
        return 'farms.weather_section.period_180';
      case '365d':
        return 'farms.weather_section.period_365';
    }
  }

  selectPeriod(period: FarmTemperatureChartPeriod): void {
    if (this.selectedPeriod === period) return;
    this.selectedPeriod = period;
    this.reload();
  }

  reload(): void {
    if (this.weatherStatus !== 'completed') return;
    this.control = { ...this.control, loading: true, error: null };
    this.loadUseCase.execute({ farmId: this.farmId, period: this.selectedPeriod });
  }

  private maybeLoadChart(): void {
    if (this.weatherStatus !== 'completed') return;
    if (this.control.chartData && this.control.chartData.period === this.selectedPeriod) return;
    this.reload();
  }

  private scheduleChartRefresh(): void {
    if (!this.viewReady) return;
    Promise.resolve().then(() => this.refreshChart());
  }

  private refreshChart(): void {
    const canvas = this.temperatureCanvasRef?.nativeElement;
    const points = this.control.chartData?.points ?? [];
    if (!canvas || points.length === 0) {
      this.chart?.destroy();
      this.chart = null;
      return;
    }

    const labels = points.map((point) => point.date);
    const datasets: ChartDataset<'line'>[] = [
      this.buildDataset(
        this.translate.instant('farms.weather_section.chart_temp_max'),
        points,
        'temperature_max',
        '#dc2626'
      ),
      this.buildDataset(
        this.translate.instant('farms.weather_section.chart_temp_mean'),
        points,
        'temperature_mean',
        '#2563eb'
      ),
      this.buildDataset(
        this.translate.instant('farms.weather_section.chart_temp_min'),
        points,
        'temperature_min',
        '#16a34a'
      )
    ];

    if (!this.chart) {
      this.chart = new Chart(canvas, {
        type: 'line',
        data: { labels, datasets },
        options: this.chartOptions()
      });
      return;
    }

    this.chart.data.labels = labels;
    this.chart.data.datasets = datasets;
    this.chart.update();
  }

  private buildDataset(
    label: string,
    data: FarmTemperatureChartPoint[],
    key: 'temperature_min' | 'temperature_mean' | 'temperature_max',
    color: string
  ): ChartDataset<'line'> {
    return {
      label,
      data: data.map((entry) => entry[key] ?? null),
      borderColor: color,
      backgroundColor: this.hexToRgba(color, 0.15),
      borderWidth: 2,
      tension: 0.3,
      pointRadius: 0,
      pointHoverRadius: 3,
      spanGaps: false,
      fill: false
    };
  }

  private chartOptions(): ChartConfiguration<'line'>['options'] {
    return {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: true, position: 'top' },
        tooltip: { mode: 'index', intersect: false }
      },
      scales: {
        x: {
          type: 'time',
          time: {
            unit: 'day',
            tooltipFormat: 'yyyy-MM-dd'
          },
          title: {
            display: true,
            text: this.translate.instant('farms.weather_section.chart_date_label')
          }
        },
        y: {
          title: {
            display: true,
            text: this.translate.instant('farms.weather_section.chart_temp_axis')
          }
        }
      }
    };
  }

  private hexToRgba(hex: string, alpha: number): string {
    const normalized = hex.replace('#', '');
    const r = parseInt(normalized.slice(0, 2), 16);
    const g = parseInt(normalized.slice(2, 4), 16);
    const b = parseInt(normalized.slice(4, 6), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }
}
