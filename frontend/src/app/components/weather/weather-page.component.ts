import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TemperatureChartComponent } from './temperature-chart.component';

@Component({
  selector: 'app-weather-page',
  standalone: true,
  imports: [CommonModule, TemperatureChartComponent],
  template: `
    <section class="page">
      <h2>Weather</h2>
      <app-temperature-chart />
    </section>
  `,
  styleUrls: ['./weather-page.component.css']
})
export class WeatherPageComponent {}
