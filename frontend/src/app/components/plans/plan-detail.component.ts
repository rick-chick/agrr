import { Component, OnInit, inject, ChangeDetectorRef, DestroyRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { TranslateModule } from '@ngx-translate/core';
import { PlanGanttClimateShellComponent } from './plan-gantt-climate-shell.component';
import { VarianceActionBannerComponent } from './variance-action-banner.component';
import { WeatherRescheduleProposalBannerComponent } from './weather-reschedule-proposal-banner.component';
import { PlanDetailView, PlanDetailViewState } from './plan-detail.view';
import { LoadPlanDetailUseCase } from '../../usecase/plans/load-plan-detail.usecase';
import { PreviewWeatherRescheduleProposalUseCase } from '../../usecase/plans/preview-weather-reschedule-proposal.usecase';
import { ApplyWeatherRescheduleProposalUseCase } from '../../usecase/plans/apply-weather-reschedule-proposal.usecase';
import { PlanDetailPresenter, PLAN_DETAIL_PROVIDERS } from '../../usecase/plans/plan-detail.providers';
import { GANTT_CHART_API_PROVIDERS } from '../../usecase/plans/gantt-chart.providers';
import { PLAN_FIELD_CLIMATE_API_PROVIDERS } from '../../usecase/plans/plan-field-climate.providers';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';
import { PlanLearnReorganizeBannerComponent } from './plan-learn-reorganize-banner.component';
import { HydrateReorganizeOrchestrationUseCase } from '../../usecase/plans/hydrate-reorganize-orchestration.usecase';
import {
  parseLearningOrchestration,
  storeLearnOrchestrationReturnToLearn
} from '../../domain/plans/learn-master-update-orchestration';
import { resolveReorganizeScreenOrchestrationMode } from '../../domain/plans/resolve-reorganize-screen-orchestration-mode';
import {
  readLearnReorganizePipelineAutoChain,
  updateLearnReorganizePipelinePhase
} from '../../domain/plans/learn-reorganize-pipeline-auto-chain';
import { dismissWeatherRescheduleProposal } from '../../domain/plans/weather-reschedule-proposal-session';
import type { WeatherRescheduleProposal } from '../../domain/plans/weather-reschedule-proposal';
import type { WeatherRescheduleAdjustMove } from '../../domain/plans/weather-reschedule-proposal-preview';

const initialControl: PlanDetailViewState = {
  loading: true,
  error: null,
  plan: null,
  planData: null,
  varianceActionItemsOnGantt: [],
  weatherProposals: [],
  activeWeatherProposalId: null,
  weatherPreviewLoading: false,
  weatherPreviewError: null,
  weatherPreview: null,
  weatherOverlayBars: [],
  weatherApplyLoading: false,
  weatherApplyError: null
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
    WeatherRescheduleProposalBannerComponent,
    PlanLearnReorganizeBannerComponent
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
        <app-plan-learn-reorganize-banner
          [planId]="planId"
          [visible]="showReoptimizationBanner"
          context="placement"
        />
        @if (activeWeatherProposal) {
          <app-weather-reschedule-proposal-banner
            [proposal]="activeWeatherProposal"
            [preview]="control.weatherPreview"
            [previewLoading]="control.weatherPreviewLoading"
            [previewError]="control.weatherPreviewError"
            [applyLoading]="control.weatherApplyLoading"
            [applyError]="control.weatherApplyError"
            (approve)="handleApproveWeatherProposal()"
            (reject)="handleRejectWeatherProposal()"
          />
        }
        @if (control.planData) {
          <app-variance-action-banner
            [planId]="planId"
            [items]="control.varianceActionItemsOnGantt"
          />
          <div class="plan-detail__body plan-detail-surface">
            <app-plan-gantt-climate-shell
              [data]="control.planData"
              [planType]="planType"
              [planId]="planId"
              [deepLinkFieldCultivationId]="deepLinkFieldCultivationId"
              [learningOrchestrationAdjust]="showReoptimizationBanner"
              [proposalOverlayBars]="control.weatherOverlayBars"
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
  private readonly previewUseCase = inject(PreviewWeatherRescheduleProposalUseCase);
  private readonly applyUseCase = inject(ApplyWeatherRescheduleProposalUseCase);
  private readonly hydrateOrchestrationUseCase = inject(HydrateReorganizeOrchestrationUseCase);
  private readonly presenter = inject(PlanDetailPresenter);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  deepLinkFieldCultivationId: number | null = null;
  learningOrchestrationMode: ReturnType<typeof parseLearningOrchestration> = null;
  private pendingWeatherProposalId: string | null = null;

  private _control: PlanDetailViewState = initialControl;
  get control(): PlanDetailViewState {
    return this._control;
  }
  set control(value: PlanDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
    this.syncActiveWeatherProposal();
  }

  readonly planType: 'private' | 'public' = 'private';

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  get showReoptimizationBanner(): boolean {
    return this.learningOrchestrationMode === 'adjust';
  }

  get activeWeatherProposal(): WeatherRescheduleProposal | null {
    const activeId = this.control.activeWeatherProposalId;
    if (!activeId) {
      return null;
    }
    return this.control.weatherProposals.find((proposal) => proposal.id === activeId) ?? null;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.route.queryParamMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((params) => {
      const raw = params.get('field_cultivation_id');
      const parsed = raw != null ? Number(raw) : NaN;
      this.deepLinkFieldCultivationId =
        Number.isFinite(parsed) && parsed > 0 ? parsed : null;
      this.pendingWeatherProposalId = params.get('weatherProposal');
      this.learningOrchestrationMode = parseLearningOrchestration(
        params.get('learningOrchestration')
      );
      this.cdr.markForCheck();
      this.syncActiveWeatherProposal();
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
    this.hydrateOrchestrationUseCase.execute(planId).subscribe({
      next: () => {
        this.applyHydratedOrchestrationState(planId);
        this.load(planId);
      },
      error: () => this.load(planId)
    });
  }

  private applyHydratedOrchestrationState(planId: number): void {
    if (this.learningOrchestrationMode != null) {
      return;
    }
    const resolvedMode = resolveReorganizeScreenOrchestrationMode(planId, 'plan_detail');
    if (resolvedMode) {
      this.learningOrchestrationMode = resolvedMode;
      this.cdr.markForCheck();
    }
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

  handleApproveWeatherProposal(): void {
    const preview = this.control.weatherPreview;
    if (!preview?.moves?.length) {
      return;
    }
    this.control = {
      ...this.control,
      weatherApplyLoading: true,
      weatherApplyError: null
    };
    this.applyUseCase.execute({
      planId: this.planId,
      planType: this.planType,
      moves: preview.moves as WeatherRescheduleAdjustMove[]
    });
  }

  handleRejectWeatherProposal(): void {
    const activeId = this.control.activeWeatherProposalId;
    if (!activeId) {
      return;
    }
    dismissWeatherRescheduleProposal(this.planId, activeId);
    this.control = {
      ...this.control,
      activeWeatherProposalId: null,
      weatherPreview: null,
      weatherPreviewError: null,
      weatherOverlayBars: [],
      weatherProposals: this.control.weatherProposals.filter(
        (proposal) => proposal.id !== activeId
      )
    };
  }

  private syncActiveWeatherProposal(): void {
    if (this.control.loading || !this.control.weatherProposals.length) {
      return;
    }
    const requestedId =
      this.pendingWeatherProposalId ?? this.control.activeWeatherProposalId ?? null;
    const resolved =
      requestedId &&
      this.control.weatherProposals.some((proposal) => proposal.id === requestedId)
        ? requestedId
        : this.control.weatherProposals[0]?.id ?? null;
    if (!resolved || resolved === this.control.activeWeatherProposalId) {
      if (
        resolved &&
        resolved === this.control.activeWeatherProposalId &&
        !this.control.weatherPreview &&
        !this.control.weatherPreviewLoading
      ) {
        this.loadWeatherPreview(resolved);
      }
      return;
    }
    this.control = {
      ...this.control,
      activeWeatherProposalId: resolved,
      weatherPreview: null,
      weatherPreviewError: null,
      weatherOverlayBars: []
    };
    this.loadWeatherPreview(resolved);
  }

  private loadWeatherPreview(proposalId: string): void {
    this.control = {
      ...this.control,
      weatherPreviewLoading: true,
      weatherPreviewError: null
    };
    this.previewUseCase.execute({ planId: this.planId, proposalId });
  }
}
