import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { PlanOptimizingComponent } from './plan-optimizing.component';
import { PlanOptimizingViewState } from './plan-optimizing.view';
import { SubscribePlanOptimizationUseCase } from '../../usecase/plans/subscribe-plan-optimization.usecase';
import { PlanOptimizingPresenter } from '../../usecase/plans/plan-optimizing.providers';
import {
  clearLearnOrchestrationProgressCache,
  hasLearnReorganizePipelineFailure,
  hydrateLearnOrchestrationProgress,
  readLearnOrchestrationReturnToLearn,
  readLearnOrchestrationStepComplete
} from '../../domain/plans/learn-master-update-orchestration';
import {
  clearLearnReorganizePipelineAutoChain,
  storeLearnReorganizePipelineAutoChain
} from '../../domain/plans/learn-reorganize-pipeline-auto-chain';

describe('PlanOptimizingComponent', () => {
  let component: PlanOptimizingComponent;
  let fixture: ComponentFixture<PlanOptimizingComponent>;
  let mockUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: PlanOptimizingPresenter;
  let mockCdr: ChangeDetectorRef;
  let mockActivatedRoute: ActivatedRoute;
  let router: Router;

  beforeEach(async () => {
    mockUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() } as unknown as PlanOptimizingPresenter;
    mockCdr = { markForCheck: vi.fn() } as unknown as ChangeDetectorRef;
    mockActivatedRoute = {
      snapshot: {
        paramMap: {
          get: vi.fn().mockReturnValue('13')
        }
      }
    } as unknown as ActivatedRoute;

    TestBed.overrideComponent(PlanOptimizingComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: SubscribePlanOptimizationUseCase, useValue: mockUseCase },
          { provide: PlanOptimizingPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: mockCdr },
          { provide: ActivatedRoute, useValue: mockActivatedRoute }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanOptimizingComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(PlanOptimizingComponent);
    component = fixture.componentInstance;
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);
    clearLearnOrchestrationProgressCache();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.optimizing_live.heading': 'Optimizing',
        'plans.optimizing_live.heading_completed': 'Optimization complete',
        'plans.optimizing_live.status_badge_completed': 'Complete',
        'plans.optimizing_live.progress_label': 'Progress: {{progress}}%',
        'plans.optimizing_live.duration_hint': 'Takes approximately 1 minute',
        'plans.optimizing_live.default_message': 'Preparing optimization...',
        'plans.optimizing_live.error.retry': 'Reload',
        'plans.optimizing_live.error.back_to_plan': 'Back to plan',
        'plans.task_schedules.orchestration.return_to_learn': 'Return to learning screen',
        'models.cultivation_plan.phases.task_schedule_generating': 'Generating task plans...',
        'models.cultivation_plan.phase_failed.default': 'Process failed'
      },
      true
    );
  });

  it('renders progress without duplicating optimizing heading and status badge', () => {
    const state: PlanOptimizingViewState = { status: 'optimizing', progress: 73, phaseMessage: '' };
    component.control = state;
    fixture.detectChanges();

    const textContent = fixture.nativeElement.textContent;
    expect(textContent).toContain('Progress: 73%');
    expect(textContent).not.toContain('Status:');
    expect((textContent.match(/Optimizing/g) ?? []).length).toBe(1);
    expect(textContent).not.toContain('Optimization complete');
    expect(fixture.nativeElement.querySelector('.status-badge')).toBeNull();
  });

  it('shows duration hint and default message while optimizing', () => {
    component.control = { status: 'optimizing', progress: 0, phaseMessage: '' };
    fixture.detectChanges();

    const textContent = fixture.nativeElement.textContent;
    expect(textContent).toContain('Takes approximately 1 minute');
    expect(textContent).toContain('Preparing optimization...');
  });

  it('does not duplicate optimizing text in ja locale', () => {
    const translate = TestBed.inject(TranslateService);
    translate.use('ja');
    translate.setTranslation(
      'ja',
      {
        'plans.optimizing_live.heading': '最適化中',
        'plans.optimizing_live.progress_label': '進捗: {{progress}}%',
        'plans.optimizing_live.duration_hint': '約1分程度かかります',
        'plans.optimizing_live.default_message': '最適化を準備しています...'
      },
      true
    );

    component.control = { status: 'optimizing', progress: 12, phaseMessage: '' };
    fixture.detectChanges();

    const textContent = fixture.nativeElement.textContent;
    expect((textContent.match(/最適化中/g) ?? []).length).toBe(1);
    expect(textContent).toContain('約1分程度かかります');
  });

  it('shows error alert with retry and back-to-plan actions on failure', () => {
    component.control = {
      status: 'failed',
      progress: 40,
      phaseMessage: 'Process failed'
    };
    fixture.detectChanges();

    const alert = fixture.nativeElement.querySelector('.page-alert-error');
    expect(alert).not.toBeNull();
    expect(alert.textContent).toContain('Process failed');

    const retry = fixture.nativeElement.querySelector('.plan-optimizing__retry');
    expect(retry).not.toBeNull();
    expect(retry.textContent).toContain('Reload');

    const backLink = fixture.nativeElement.querySelector('a.plan-optimizing__back');
    expect(backLink).not.toBeNull();
    expect(backLink.getAttribute('href')).toBe('/plans/13');
    expect(backLink.textContent).toContain('Back to plan');
  });

  it('shows phase message from cable when present', () => {
    component.control = {
      status: 'optimizing',
      progress: 90,
      phaseMessage: 'Generating task plans...'
    };
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('Generating task plans...');
  });

  it('shows completed heading when progress reaches 100%', () => {
    component.control = { status: 'optimizing', progress: 100, phaseMessage: '' };
    fixture.detectChanges();

    const textContent = fixture.nativeElement.textContent;
    expect(textContent).toContain('Optimization complete');
    expect(textContent).toContain('Complete');
    expect(textContent).not.toContain('Optimizing');
    expect(textContent).toContain('Progress: 100%');
  });

  it('navigates to plan detail when optimization completes', () => {
    component.onOptimizationCompleted();

    expect(router.navigate).toHaveBeenCalledWith(['/plans', 13]);
  });

  it('navigates to task schedule regenerate when auto-chain pipeline is active', () => {
    storeLearnReorganizePipelineAutoChain(13);

    component.onOptimizationCompleted();

    expect(router.navigate).toHaveBeenCalledWith(['/plans', 13, 'task_schedule'], {
      queryParams: { learningOrchestration: 'regenerate' }
    });
    expect(readLearnOrchestrationStepComplete(13, 'placement')).toBe(true);
    clearLearnReorganizePipelineAutoChain(13);
  });

  it('returns to learn and records pipeline failure when optimization fails during auto-chain', () => {
    storeLearnReorganizePipelineAutoChain(13);

    component.control = {
      status: 'failed',
      progress: 40,
      phaseMessage: 'Process failed'
    };

    expect(hasLearnReorganizePipelineFailure(13)).toBe(true);
    expect(router.navigate).toHaveBeenCalledWith(['/plans', 13, 'learn']);
    clearLearnReorganizePipelineAutoChain(13);
  });

  it('navigates to learn when orchestration return context is set', () => {
    hydrateLearnOrchestrationProgress(13, { return_to_learn: true });

    component.onOptimizationCompleted();

    expect(router.navigate).toHaveBeenCalledWith(['/plans', 13, 'learn']);
    expect(readLearnOrchestrationReturnToLearn(13)).toBe(false);
  });

  it('marks placement orchestration step complete when returning to learn', () => {
    hydrateLearnOrchestrationProgress(13, { return_to_learn: true });

    component.onOptimizationCompleted();

    expect(readLearnOrchestrationStepComplete(13, 'placement')).toBe(true);
  });

  it('initializes with the presenter and executes the use case', () => {
    component.ngOnInit();

    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(mockUseCase.execute).toHaveBeenCalledWith({
      planId: 13,
      onSubscribed: expect.any(Function)
    });
  });

  it('reloads optimization subscription when retry is clicked', () => {
    component.control = {
      status: 'failed',
      progress: 40,
      phaseMessage: 'Process failed'
    };
    fixture.detectChanges();

    mockUseCase.execute.mockClear();
    const retry = fixture.nativeElement.querySelector('.plan-optimizing__retry');
    retry?.click();

    expect(mockUseCase.execute).toHaveBeenCalledWith({
      planId: 13,
      onSubscribed: expect.any(Function)
    });
    expect(component.control.status).toBe('pending');
    expect(component.control.progress).toBe(0);
  });

  it('renders plan context header without redundant breadcrumb links while optimizing', () => {
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-context-header__crumbs')).toBeNull();
    expect(fixture.nativeElement.querySelector('a.plan-context-header__back')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-plan-detail-context-nav')).toBeNull();
  });

  it('shows learn reorganize banner with return-to-learn link during orchestration', () => {
    hydrateLearnOrchestrationProgress(13, { return_to_learn: true });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-plan-learn-reorganize-banner')).toBeTruthy();
    const learnLink = fixture.nativeElement.querySelector('a.learn-reorganize-banner__learn-link');
    expect(learnLink).not.toBeNull();
    expect(learnLink.getAttribute('href')).toBe('/plans/13/learn');
    expect(
      fixture.nativeElement.querySelector('app-plan-learn-loop-progress-strip')
    ).not.toBeNull();
  });
});
