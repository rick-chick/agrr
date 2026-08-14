import { Component, OnInit, inject, ChangeDetectorRef, DestroyRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { TranslateModule } from '@ngx-translate/core';
import { PlanGanttClimateShellComponent } from './plan-gantt-climate-shell.component';
import { VarianceActionBannerComponent } from './variance-action-banner.component';
import { PlanDetailView, PlanDetailViewState } from './plan-detail.view';
import { LoadPlanDetailUseCase } from '../../usecase/plans/load-plan-detail.usecase';
import { PlanDetailPresenter, PLAN_DETAIL_PROVIDERS } from '../../usecase/plans/plan-detail.providers';
import { GANTT_CHART_API_PROVIDERS } from '../../usecase/plans/gantt-chart.providers';
import { PLAN_FIELD_CLIMATE_API_PROVIDERS } from '../../usecase/plans/plan-field-climate.providers';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';
import { PlanReoptimizationBannerComponent } from './plan-reoptimization-banner.component';
import {
  parseLearningOrchestration,
  storeLearnOrchestrationReturnToLearn
} from '../../domain/plans/learn-master-update-orchestration';
import {
  readLearnReorganizePipelineAutoChain,
  updateLearnReorganizePipelinePhase
} from '../../domain/plans/learn-reorganize-pipeline-auto-chain';

const initialControl: PlanDetailViewState = {
  loading: true,
  error: null,
  plan: null,
  planData: null,
  varianceActionItemsOnGantt: []
};

@Component({
  selector: 'app-plan-detail',
  standalone: true,
  imports: [
    CommonModule,
    PlanGanttClimateShellComponent,
    TranslateModule,
    PlanPlanContextHeaderComponent,
    VarianceActionBannerComponent,
    PlanReoptimizationBannerComponent
  ],
  providers: [
    ...PLAN_DETAIL_PROVIDERS,
    ...GANTT_CHART_API_PROVIDERS,
    ...PLAN_FIELD_CLIMATE_API_PROVIDERS
  ],
  template: `
    <div class="page-main">
      <app-plan-plan-context-header
        [planId]="planId"
        [planName]="control.plan?.name ?? null"
        pageTitleKey="plans.show.page_title"
      />
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <div class="plan-detail__alert" role="alert">
          <p>{{ control.error | translate }}</p>
        </div>
      } @else if (control.plan) {
        @if (control.planData) {
          <app-variance-action-banner
            [planId]="planId"
            [items]="control.varianceActionItemsOnGantt"
          />
          <app-plan-reoptimization-banner [visible]="showReoptimizationBanner" [planId]="planId" />
          <div class="plan-detail__body plan-detail-surface">
            <app-plan-gantt-climate-shell
              [data]="control.planData"
              [planType]="planType"
              [planId]="planId"
              [deepLinkFieldCultivationId]="deepLinkFieldCultivationId"
              [learningOrchestrationAdjust]="showReoptimizationBanner"
              (adjustOrchestrationStarted)="handleAdjustOrchestrationStarted()"
            />
          </div>
        }
      }
    </div>
  `,
  styleUrls: ['./plan-detail.component.css']
})
export class PlanDetailComponent implements PlanDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadPlanDetailUseCase);
  private readonly presenter = inject(PlanDetailPresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  deepLinkFieldCultivationId: number | null = null;
  learningOrchestrationMode: ReturnType<typeof parseLearningOrchestration> = null;

  private _control: PlanDetailViewState = initialControl;
  get control(): PlanDetailViewState {
    return this._control;
  }
  set control(value: PlanDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  readonly planType: 'private' | 'public' = 'private';

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  get showReoptimizationBanner(): boolean {
    return this.learningOrchestrationMode === 'adjust';
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.route.queryParamMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((params) => {
      const raw = params.get('field_cultivation_id');
      const parsed = raw != null ? Number(raw) : NaN;
      this.deepLinkFieldCultivationId =
        Number.isFinite(parsed) && parsed > 0 ? parsed : null;
      this.learningOrchestrationMode = parseLearningOrchestration(
        params.get('learningOrchestration')
      );
      this.cdr.markForCheck();
    });

    const planId = Number(this.route.snapshot.paramMap.get('id'));
    if (!planId) {
      this.control = {
        ...initialControl,
        loading: false,
        error: 'plans.errors.invalid_id'
      };
      return;
    }
    this.load(planId);
  }

  load(planId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ planId });
  }

  handleAdjustOrchestrationStarted(): void {
    const planId = this.planId;
    if (!planId || !this.showReoptimizationBanner) {
      return;
    }
    if (readLearnReorganizePipelineAutoChain(planId)) {
      updateLearnReorganizePipelinePhase(planId, 'optimizing');
    } else {
      storeLearnOrchestrationReturnToLearn(planId);
    }
    void this.router.navigate(['/plans', planId, 'optimizing']);
  }
}
