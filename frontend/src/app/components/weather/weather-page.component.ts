import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TemperatureChartComponent } from './temperature-chart.component';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-weather-page',
  standalone: true,
  imports: [CommonModule, TemperatureChartComponent, TranslateModule],
  template: `
    <main class="page-main">
      <section class="page">
        <h2>{{ 'weather.page.heading' | translate }}</h2>
        <app-temperature-chart />
      </section>
    </main>
  `,
  styleUrls: ['./weather-page.component.css']
})
export class WeatherPageComponent {}
