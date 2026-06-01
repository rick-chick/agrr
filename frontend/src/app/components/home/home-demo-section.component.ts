import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { Subscription } from 'rxjs';
import { PlanGanttClimateShellComponent } from '../plans/plan-gantt-climate-shell.component';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import {
  HOME_DEMO_HINT_I18N_KEYS,
  HOME_INDEX_DEMO_UI_I18N_KEYS
} from '../../domain/plans/home-index.content';
import { HOME_DEMO_SECTION_I18N_KEYS } from '../../domain/plans/landing-demo-i18n.keys';
import {
  buildHomeDemoTitleParams,
  HomeDemoTitleParams
} from '../../domain/plans/landing-demo-labels';
import { DemoGanttPlanStore } from '../../services/plans/demo-gantt-plan-store.service';

@Component({
  selector: 'app-home-demo-section',
  standalone: true,
  imports: [TranslateModule, PlanGanttClimateShellComponent],
  template: `
    <section id="home-demo" class="home-demo-section" aria-labelledby="home-demo-heading">
      <h2 id="home-demo-heading">{{
        HOME_DEMO_SECTION_I18N_KEYS.title | translate: demoTitleParams
      }}</h2>
      <ul class="home-demo-hints" [attr.aria-label]="demoUi.hintsAria | translate">
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
      <p class="home-demo-section__disclaimer">{{ demoUi.disclaimer | translate }}</p>
      <div class="home-demo-section__actions">
        <button type="button" class="primary-button large" (click)="navigateToPlan()">
          {{ demoUi.ctaCreate | translate }}
        </button>
      </div>
    </section>
  `,
  styleUrls: [
    './home-demo-section.component.css',
    '../plans/plan-detail-surface.css',
    '../public-plans/public-plan.component.css'
  ]
})
export class HomeDemoSectionComponent implements OnInit, OnDestroy {
  readonly HOME_DEMO_SECTION_I18N_KEYS = HOME_DEMO_SECTION_I18N_KEYS;
  readonly demoUi = HOME_INDEX_DEMO_UI_I18N_KEYS;
  readonly demoHintKeys = HOME_DEMO_HINT_I18N_KEYS;

  private readonly router = inject(Router);
  private readonly demoStore = inject(DemoGanttPlanStore);
  private readonly translate = inject(TranslateService);
  private langChangeSub: Subscription | null = null;

  demoPlanData: CultivationPlanData | null = null;
  demoTitleParams: HomeDemoTitleParams = {
    schedule: '',
    preview: '',
    separator: ''
  };

  ngOnInit(): void {
    this.applyDemoLocale();
    this.langChangeSub = this.translate.onLangChange.subscribe(() => this.applyDemoLocale());
  }

  ngOnDestroy(): void {
    this.langChangeSub?.unsubscribe();
  }

  navigateToPlan(): void {
    this.router.navigate(['/public-plans/new']);
  }

  private applyDemoLocale(): void {
    this.demoPlanData = this.demoStore.syncFromTranslate(this.translate);
    this.demoTitleParams = buildHomeDemoTitleParams(this.translate);
  }
}
