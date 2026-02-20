import { Component, Inject } from '@angular/core';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <section class="hero-section">
      <h1>{{ 'home.index.hero.title' | translate }}</h1>
      <p [innerHTML]="'home.index.hero.subtitle_html' | translate"></p>
      <button (click)="navigateToPlan()" class="primary-button large">{{ 'home.index.hero.cta_button' | translate }}</button>
    </section>
    
    <section class="features-section">
      <h2>{{ 'home.index.features.title' | translate }}</h2>
      <p class="features-subtitle">{{ 'home.index.features.subtitle' | translate }}</p>
      <div class="features-grid">
        @for (feature of features; track feature.titleKey) {
          <div class="feature-card">
            <div class="feature-icon">{{ feature.icon }}</div>
            <h3>{{ feature.titleKey | translate }}</h3>
            <p>{{ feature.descKey | translate }}</p>
          </div>
        }
      </div>
    </section>
    
    <section class="cta-section">
      <button (click)="navigateToPlan()" class="primary-button">{{ 'home.index.hero.cta_button' | translate }}</button>
    </section>
  `,
  styleUrls: ['./home.component.css']
})
export class HomeComponent {
  features = [
    { icon: '📈', titleKey: 'home.index.features.growth_prediction.title', descKey: 'home.index.features.growth_prediction.description' },
    { icon: '🌤️', titleKey: 'home.index.features.weather.title', descKey: 'home.index.features.weather.description' },
    { icon: '📊', titleKey: 'home.index.features.optimization.title', descKey: 'home.index.features.optimization.description' },
  ];

  constructor(public readonly authService: AuthService, private router: Router) {}

  navigateToPlan() {
    this.router.navigate(['/public-plans/new']);
  }
}
