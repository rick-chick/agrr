import { Component, inject } from '@angular/core';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { scrollToElementId } from '../../core/dom/scroll-to-element-id';
import {
  HOME_INDEX_FEATURES,
  HOME_INDEX_FEATURES_HEADING_I18N_KEYS,
  HOME_INDEX_HERO_I18N_KEYS
} from '../../domain/plans/home-index.content';
import { PUBLIC_PLAN_CREATE_ROUTE } from '../../routes/public-plans.routes';
import { HomeDemoSectionComponent } from './home-demo-section.component';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [TranslateModule, HomeDemoSectionComponent],
  template: `
    <section class="hero-section">
      <h1>{{ hero.title | translate }}</h1>
      <p [innerHTML]="hero.subtitleHtml | translate"></p>
      <div class="hero-actions">
        <a href="#home-demo" class="btn btn-secondary" (click)="scrollToDemo($event)">
          {{ hero.ctaScrollDemo | translate }}
        </a>
      </div>
    </section>

    <app-home-demo-section />

    <section class="features-section" aria-labelledby="home-features-heading">
      <h2 id="home-features-heading">{{ featuresHeading.title | translate }}</h2>
      <p class="features-subtitle">{{ featuresHeading.subtitle | translate }}</p>
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

    <section class="cta-section cta-section--footer">
      <button type="button" class="btn-link" (click)="navigateToPlan()">
        {{ hero.ctaFooterLink | translate }}
      </button>
    </section>
  `,
  styleUrls: ['./home.component.css']
})
export class HomeComponent {
  readonly hero = HOME_INDEX_HERO_I18N_KEYS;
  readonly featuresHeading = HOME_INDEX_FEATURES_HEADING_I18N_KEYS;
  readonly features = HOME_INDEX_FEATURES;

  private readonly router = inject(Router);

  scrollToDemo(event: Event): void {
    event.preventDefault();
    scrollToElementId('home-demo');
  }

  navigateToPlan(): void {
    void this.router.navigate(PUBLIC_PLAN_CREATE_ROUTE);
  }
}
