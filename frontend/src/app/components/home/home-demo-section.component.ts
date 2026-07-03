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
import { buildLandingDemoLabels } from '../../domain/plans/landing-demo-labels';
import { PUBLIC_PLAN_CREATE_ROUTE } from '../../routes/public-plans.routes';
import { HomeDemoSectionView } from './home-demo-section.view';
import {
  HOME_DEMO_SECTION_PROVIDERS,
  HomeDemoSectionPresenter
} from '../../usecase/plans/home-demo-section.providers';
import { SyncLandingDemoPlanUseCase } from '../../usecase/plans/sync-landing-demo-plan.usecase';

@Component({
  selector: 'app-home-demo-section',
  standalone: true,
  imports: [TranslateModule, PlanGanttClimateShellComponent],
  providers: [...HOME_DEMO_SECTION_PROVIDERS],
  template: `
    <section
      id="home-demo"
      class="home-demo-section"
      [attr.aria-label]="demoUi.hintsAria | translate"
    >
      <ul class="home-demo-hints" [attr.aria-label]="demoUi.hintsAria | translate">
        @for (hintKey of demoHintKeys; track hintKey) {
          <li class="home-demo-hint">{{ hintKey | translate }}</li>
        }
      </ul>
      <div class="home-demo-gantt plan-detail-surface">
        <app-plan-gantt-climate-shell [data]="demoPlanData" planType="demo" />
      </div>
      <div class="home-demo-section__actions">
        <button type="button" class="primary-button large" (click)="navigateToPlan()">
          {{ demoUi.ctaCreate | translate }}
        </button>
      </div>
    </section>
  `,
  styleUrls: ['./home-demo-section.component.css', '../plans/plan-detail-surface.css']
})
export class HomeDemoSectionComponent implements OnInit, OnDestroy, HomeDemoSectionView {
  readonly demoUi = HOME_INDEX_DEMO_UI_I18N_KEYS;
  readonly demoHintKeys = HOME_DEMO_HINT_I18N_KEYS;

  private readonly router = inject(Router);
  private readonly translate = inject(TranslateService);
  private readonly homeDemoPresenter = inject(HomeDemoSectionPresenter);
  private readonly syncLandingDemoPlanUseCase = inject(SyncLandingDemoPlanUseCase);
  private langChangeSub: Subscription | null = null;

  demoPlanData!: CultivationPlanData;

  ngOnInit(): void {
    this.homeDemoPresenter.setView(this);
    this.syncLocalizedDemoPlan();
    this.langChangeSub = this.translate.onLangChange.subscribe(() => this.syncLocalizedDemoPlan());
  }

  ngOnDestroy(): void {
    this.langChangeSub?.unsubscribe();
  }

  applyDemoPlanData(planData: CultivationPlanData): void {
    this.demoPlanData = planData;
  }

  navigateToPlan(): void {
    void this.router.navigate(PUBLIC_PLAN_CREATE_ROUTE);
  }

  private syncLocalizedDemoPlan(): void {
    this.syncLandingDemoPlanUseCase.execute({
      labels: buildLandingDemoLabels(this.translate)
    });
  }
}
