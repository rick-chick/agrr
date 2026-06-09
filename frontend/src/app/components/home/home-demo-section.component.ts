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
import { PUBLIC_PLAN_CREATE_ROUTE } from '../../routes/public-plans.routes';
import { DemoGanttPlanStore } from '../../services/plans/demo-gantt-plan-store.service';

@Component({
  selector: 'app-home-demo-section',
  standalone: true,
  imports: [TranslateModule, PlanGanttClimateShellComponent],
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
export class HomeDemoSectionComponent implements OnInit, OnDestroy {
  readonly demoUi = HOME_INDEX_DEMO_UI_I18N_KEYS;
  readonly demoHintKeys = HOME_DEMO_HINT_I18N_KEYS;

  private readonly router = inject(Router);
  private readonly demoStore = inject(DemoGanttPlanStore);
  private readonly translate = inject(TranslateService);
  private langChangeSub: Subscription | null = null;

  demoPlanData!: CultivationPlanData;

  constructor() {
    this.refreshViewState();
  }

  ngOnInit(): void {
    this.langChangeSub = this.translate.onLangChange.subscribe(() => this.refreshViewState());
  }

  ngOnDestroy(): void {
    this.langChangeSub?.unsubscribe();
  }

  navigateToPlan(): void {
    void this.router.navigate(PUBLIC_PLAN_CREATE_ROUTE);
  }

  private refreshViewState(): void {
    this.demoPlanData = this.demoStore.syncHomeDemoViewState(this.translate).planData;
  }
}
