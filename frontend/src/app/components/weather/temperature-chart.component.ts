import { Component } from '@angular/core';
import { BaseChartDirective } from 'ng2-charts';
import { ChartConfiguration } from 'chart.js';

@Component({
  selector: 'app-temperature-chart',
  standalone: true,
  imports: [BaseChartDirective],
  template: `
    <div class="chart">
      <h3>Temperature Chart</h3>
      <canvas baseChart [data]="chartData" [options]="chartOptions" [type]="'line'"></canvas>
    </div>
  `,
  styleUrls: ['./temperature-chart.component.css']
})
export class TemperatureChartComponent {
  chartData: ChartConfiguration<'line'>['data'] = {
    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    datasets: [{ data: [12, 14, 13, 15, 16], label: 'Temp (°C)' }]
  };

  chartOptions: ChartConfiguration<'line'>['options'] = {
    responsive: true
  };
}
