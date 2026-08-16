import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter, Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { of, type Observable } from 'rxjs';
import type { ParamMap } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanDetailComponent } from './plan-detail.component';
import { PlanDetailViewState } from './plan-detail.view';
import { LoadPlanDetailUseCase } from '../../usecase/plans/load-plan-detail.usecase';
import { PreviewWeatherRescheduleProposalUseCase } from '../../usecase/plans/preview-weather-reschedule-proposal.usecase';
import { ApplyWeatherRescheduleProposalUseCase } from '../../usecase/plans/apply-weather-reschedule-proposal.usecase';
import { PlanDetailPresenter } from '../../usecase/plans/plan-detail.providers';
import { HydrateReorganizeOrchestrationUseCase } from '../../usecase/plans/hydrate-reorganize-orchestration.usecase';
import {
  clearLearnOrchestrationProgressCache,
  hydrateLearnOrchestrationProgress,
  readLearnOrchestrationReturnToLearn
} from '../../domain/plans/learn-master-update-orchestration';
import {
  clearPlanPostSaveOnboardingSession,
  markPlanPostSaveOnboarding
} from '../../domain/plans/plan-post-save-onboarding-session';

describe('PlanDetailComponent', () => {
  let component: PlanDetailComponent;
  let fixture: ComponentFixture<PlanDetailComponent>;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let hydrateUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let activatedRoute: {
    snapshot: { paramMap: { get: ReturnType<typeof vi.fn> } };
    queryParamMap: Observable<ParamMap>;
  };
  let cdr: ChangeDetectorRef;

  beforeEach(() => {
    loadUseCase = { execute: vi.fn(() => of(undefined)) };
    hydrateUseCase = { execute: vi.fn(() => of(null)) };
    mockPresenter = { setView: vi.fn() };
    activatedRoute = {
      snapshot: {
        paramMap: { get: vi.fn(() => '1') }
      },
      queryParamMap: of(convertToParamMap({}))
    };

    TestBed.resetTestingModule();
    TestBed.overrideComponent(PlanDetailComponent, {
      set: {
        providers: [
          { provide: LoadPlanDetailUseCase, useValue: loadUseCase },
          { provide: PreviewWeatherRescheduleProposalUseCase, useValue: { execute: vi.fn() } },
          { provide: ApplyWeatherRescheduleProposalUseCase, useValue: { execute: vi.fn() } },
          { provide: HydrateReorganizeOrchestrationUseCase, useValue: hydrateUseCase },
          { provide: PlanDetailPresenter, useValue: mockPresenter }
        ]
      }
    });
    TestBed.configureTestingModule({
      imports: [PlanDetailComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: ActivatedRoute, useValue: activatedRoute }
      ]
    });

    fixture = TestBed.createComponent(PlanDetailComponent);
    component = fixture.componentInstance;
    cdr = (component as unknown as { cdr: ChangeDetectorRef }).cdr;
  });

  afterEach(() => {
    clearLearnOrchestrationProgressCache();
    clearPlanPostSaveOnboardingSession();
    vi.restoreAllMocks();
  });

  it('implements View control getter/setter', () => {
    const state: PlanDetailViewState = {
      loading: false,
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
    const markForCheckSpy = vi.spyOn(cdr, 'markForCheck');
    component.control = state;
    expect(component.control).toEqual(state);
    expect(markForCheckSpy).toHaveBeenCalled();
  });

  it('uses the unified plan context header layout', () => {
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: null,
      plan: {
        id: 1,
        name: 'Plan A',
        status: 'completed',
        farm_id: 1
      },
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
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-plan-plan-context-header')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.plan-detail__title')).toBeNull();
    expect(fixture.nativeElement.querySelector('.plan-context-header__crumbs')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('a.plan-context-header__back')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('app-plan-detail-context-nav')).toBeTruthy();
    const navLinks = fixture.nativeElement.querySelectorAll('.plan-context-nav__link');
    expect(navLinks.length).toBe(5);
  });

  it('enables reoptimization banner when learningOrchestration is adjust', () => {
    component.learningOrchestrationMode = 'adjust';
    expect(component.showReoptimizationBanner).toBe(true);
  });

  it('shows learn reorganize banner with progress strip when adjust orchestration is active', () => {
    activatedRoute.queryParamMap = of(
      convertToParamMap({ learningOrchestration: 'adjust' })
    );
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: null,
      plan: {
        id: 1,
        name: 'Plan A',
        status: 'completed',
        farm_id: 1
      },
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
    fixture.detectChanges();

    expect(component.showReoptimizationBanner).toBe(true);

    expect(fixture.nativeElement.querySelector('app-plan-learn-reorganize-banner')).toBeTruthy();
    expect(
      fixture.nativeElement.querySelector('app-plan-learn-loop-progress-strip')
    ).not.toBeNull();
    const learnLink = fixture.nativeElement.querySelector('a.learn-reorganize-banner__learn-link');
    expect(learnLink).not.toBeNull();
    expect(learnLink.getAttribute('href')).toBe('/plans/1/learn');
  });

  it('hydrates orchestration on init and shows reorganize banner after reload', () => {
    hydrateUseCase.execute = vi.fn(() => {
      hydrateLearnOrchestrationProgress(1, {
        pipeline_active: true,
        current_phase: 'placement'
      });
      return of(null);
    });

    fixture.detectChanges();

    expect(hydrateUseCase.execute).toHaveBeenCalledWith(1);
    expect(component.showReoptimizationBanner).toBe(true);
    expect(loadUseCase.execute).toHaveBeenCalled();
  });

  it('navigates to optimizing and stores learn return context when adjust orchestration starts', () => {
    const router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);
    clearLearnOrchestrationProgressCache();

    component.learningOrchestrationMode = 'adjust';
    component.handleAdjustOrchestrationStarted();

    expect(router.navigate).toHaveBeenCalledWith(['/plans', 1, 'optimizing']);
    expect(readLearnOrchestrationReturnToLearn(1)).toBe(true);
  });

  it('shows post-save onboarding banner after public plan save handoff', () => {
    markPlanPostSaveOnboarding(1);
    fixture.detectChanges();
    component.control = {
      loading: false,
      error: null,
      plan: {
        id: 1,
        name: 'Plan A',
        status: 'completed',
        farm_id: 1
      },
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
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-plan-post-save-banner')).toBeTruthy();
    expect(component.showPostSaveBanner).toBe(true);
  });

  it('hides post-save banner after dismiss', () => {
    markPlanPostSaveOnboarding(1);
    fixture.detectChanges();
    component.showPostSaveBanner = true;
    component.handleDismissPostSaveBanner();
    fixture.detectChanges();

    expect(component.showPostSaveBanner).toBe(false);
  });
});
