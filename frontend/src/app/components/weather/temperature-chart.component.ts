import { Component, inject, OnInit } from '@angular/core';
import { BaseChartDirective } from 'ng2-charts';
import { ChartConfiguration } from 'chart.js';
import { TranslateModule, TranslateService } from '@ngx-translate/core';

@Component({
  selector: 'app-temperature-chart',
  standalone: true,
  imports: [BaseChartDirective, TranslateModule],
  template: `
    <div class="chart">
      <h3>{{ 'weather.temperature.chart.title' | translate }}</h3>
      <canvas baseChart [data]="chartData" [options]="chartOptions" [type]="'line'"></canvas>
    </div>
  `,
  styleUrls: ['./temperature-chart.component.css']
})
export class TemperatureChartComponent implements OnInit {
  private readonly translate = inject(TranslateService);

  chartData: ChartConfiguration<'line'>['data'] = {
    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    datasets: [{ data: [12, 14, 13, 15, 16], label: '' }]
  };

  chartOptions: ChartConfiguration<'line'>['options'] = {
    responsive: true
  };

  ngOnInit(): void {
    if (this.chartData.datasets && this.chartData.datasets.length > 0) {
      this.chartData.datasets[0].label = this.translate.instant('weather.temperature.chart.dataset_label');
    }
  }
}
