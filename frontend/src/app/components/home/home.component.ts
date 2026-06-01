import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { Subscription } from 'rxjs';
import { PlanGanttClimateShellComponent } from '../plans/plan-gantt-climate-shell.component';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { DemoGanttPlanStore } from '../../services/plans/demo-gantt-plan-store.service';
import { HOME_DEMO_SECTION_I18N_KEYS } from '../../domain/plans/landing-demo-i18n.keys';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [TranslateModule, PlanGanttClimateShellComponent],
  template: `
    <section class="hero-section">
      <h1>{{ 'home.index.hero.title' | translate }}</h1>
      <p [innerHTML]="'home.index.hero.subtitle_html' | translate"></p>
      <div class="hero-actions">
        <a href="#home-demo" class="hero-scroll-button" (click)="scrollToDemo($event)">
          {{ 'home.index.hero.cta_scroll_demo' | translate }}
        </a>
      </div>
    </section>

    <section id="home-demo" class="home-demo-section" aria-labelledby="home-demo-heading">
      <h2 id="home-demo-heading">{{ demoSectionTitle }}</h2>
      <ul class="home-demo-hints" [attr.aria-label]="'home.index.demo.hints_aria' | translate">
        @for (hintKey of demoHintKeys; track hintKey) {
          <li class="home-demo-hint">{{ hintKey | translate }}</li>
        }
      </ul>
      @if (demoPlanData) {
        <div class="home-demo-gantt-wrap">
          <div class="home-demo-gantt__chrome">
            <span class="home-demo-gantt__badge">{{
              HOME_DEMO_SECTION_I18N_KEYS.preview | translate
            }}</span>
          </div>
          <div class="home-demo-gantt plan-detail-surface">
            <app-plan-gantt-climate-shell [data]="demoPlanData" planType="demo" />
          </div>
        </div>
      }
      <p class="home-demo-section__disclaimer">{{ 'home.index.demo.disclaimer' | translate }}</p>
      <div class="home-demo-section__actions">
        <button type="button" class="primary-button large" (click)="navigateToPlan()">
          {{ 'home.index.demo.cta_create' | translate }}
        </button>
      </div>
    </section>

    <section class="features-section" aria-labelledby="home-features-heading">
      <h2 id="home-features-heading">{{ 'home.index.features.title' | translate }}</h2>
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

    <section class="cta-section cta-section--footer">
      <button type="button" class="cta-footer-link" (click)="navigateToPlan()">
        {{ 'home.index.hero.cta_footer_link' | translate }}
      </button>
    </section>
  `,
  styleUrls: [
    './home.component.css',
    '../plans/plan-detail-surface.css',
    '../public-plans/public-plan.component.css'
  ]
})
export class HomeComponent implements OnInit, OnDestroy {
  readonly HOME_DEMO_SECTION_I18N_KEYS = HOME_DEMO_SECTION_I18N_KEYS;

  private readonly router = inject(Router);
  private readonly demoStore = inject(DemoGanttPlanStore);
  private readonly translate = inject(TranslateService);
  private langChangeSub: Subscription | null = null;

  demoPlanData: CultivationPlanData | null = null;
  demoTitleParams: { schedule: string; preview: string; separator: string } = {
    schedule: '',
    preview: '',
    separator: ''
  };

  readonly demoHintKeys = [
    'home.index.demo.hints.drag',
    'home.index.demo.hints.tap',
    'home.index.demo.hints.add'
  ] as const;

  features = [
    {
      icon: '📈',
      titleKey: 'home.index.features.growth_prediction.title',
      descKey: 'home.index.features.growth_prediction.description'
    },
    {
      icon: '🌤️',
      titleKey: 'home.index.features.weather.title',
      descKey: 'home.index.features.weather.description'
    },
    {
      icon: '📊',
      titleKey: 'home.index.features.optimization.title',
      descKey: 'home.index.features.optimization.description'
    }
  ];

  ngOnInit(): void {
    this.applyDemoLocale();
    this.langChangeSub = this.translate.onLangChange.subscribe(() => this.applyDemoLocale());
  }

  ngOnDestroy(): void {
    this.langChangeSub?.unsubscribe();
  }

  scrollToDemo(event: Event): void {
    event.preventDefault();
    document.getElementById('home-demo')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  navigateToPlan(): void {
    this.router.navigate(['/public-plans/new']);
  }

  private applyDemoLocale(): void {
    this.demoPlanData = this.demoStore.syncFromTranslate(this.translate);
    this.demoTitleParams = {
      schedule: this.translate.instant(HOME_DEMO_SECTION_I18N_KEYS.schedule),
      preview: this.translate.instant(HOME_DEMO_SECTION_I18N_KEYS.preview),
      separator: this.translate.instant(HOME_DEMO_SECTION_I18N_KEYS.separator)
    };
  }
}
