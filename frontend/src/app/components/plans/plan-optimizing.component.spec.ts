import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { PlanOptimizingComponent } from './plan-optimizing.component';
import { PlanOptimizingViewState } from './plan-optimizing.view';
import { SubscribePlanOptimizationUseCase } from '../../usecase/plans/subscribe-plan-optimization.usecase';
import { PlanOptimizingPresenter } from '../../usecase/plans/plan-optimizing.providers';

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

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.optimizing_live.back_to_plan': 'Back to plan',
        'plans.optimizing_live.heading': 'Optimizing',
        'plans.optimizing_live.heading_completed': 'Optimization complete',
        'plans.optimizing_live.status_badge': 'Optimizing',
        'plans.optimizing_live.status_badge_completed': 'Complete',
        'plans.optimizing_live.progress_label': 'Progress: {{progress}}%',
        'models.cultivation_plan.phases.task_schedule_generating': 'Generating task schedules...'
      },
      true
    );
  });

  it('renders progress without showing the redundant status label', () => {
    const state: PlanOptimizingViewState = { status: 'optimizing', progress: 73, phaseMessage: '' };
    component.control = state;
    fixture.detectChanges();

    const textContent = fixture.nativeElement.textContent;
    expect(textContent).toContain('Progress: 73%');
    expect(textContent).not.toContain('Status:');
    expect(textContent).toContain('Optimizing');
    expect(textContent).not.toContain('Optimization complete');
  });

  it('shows phase message from cable when present', () => {
    component.control = {
      status: 'optimizing',
      progress: 90,
      phaseMessage: 'Generating task schedules...'
    };
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain('Generating task schedules...');
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

  it('initializes with the presenter and executes the use case', () => {
    component.ngOnInit();

    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(mockUseCase.execute).toHaveBeenCalledWith({
      planId: 13,
      onSubscribed: expect.any(Function)
    });
  });
});
