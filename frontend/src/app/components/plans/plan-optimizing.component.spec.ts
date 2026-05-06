import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
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

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.optimizing_live.back_to_plan': 'Back to plan',
        'plans.optimizing_live.heading': 'Optimizing',
        'plans.optimizing_live.progress_label': 'Progress: {{progress}}%'
      },
      true
    );
  });

  it('renders progress without showing the redundant status label', () => {
    const state: PlanOptimizingViewState = { status: 'optimizing', progress: 73 };
    component.control = state;
    fixture.detectChanges();

    const textContent = fixture.nativeElement.textContent;
    expect(textContent).toContain('Progress: 73%');
    expect(textContent).not.toContain('Status:');
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
