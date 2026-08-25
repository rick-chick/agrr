import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, ActivatedRoute } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PlanNewComponent } from './plan-new.component';
import { LoadPrivatePlanFarmsUseCase } from '../../usecase/private-plan-create/load-private-plan-farms.usecase';
import { CreatePrivatePlanUseCase } from '../../usecase/private-plan-create/create-private-plan.usecase';
import { PlanNewPresenter } from '../../usecase/plans/plan-new.providers';
import { CreatePrivatePlanPresenter } from '../../adapters/private-plan-create/create-private-plan.presenter';
import { LoadPlanNewCarryoverUseCase } from '../../usecase/plans/load-plan-new-carryover.usecase';
import { LoadPlanNewReadinessUseCase } from '../../usecase/plans/load-plan-new-readiness.usecase';
import { PlanNewViewState } from './plan-new.view';
import { buildPlanCreateReadiness } from '../../domain/plans/plan-create-readiness';

function defaultControl(overrides: Partial<PlanNewViewState> = {}): PlanNewViewState {
  return {
    loading: false,
    submitting: false,
    error: null,
    farms: [],
    selectedFarmId: null,
    readinessLoading: false,
    readiness: null,
    noFieldsWarning: false,
    carryoverEnabled: false,
    sourcePlans: [],
    selectedSourcePlanId: null,
    carryoverPreviewLoading: false,
    carryoverPreviewError: null,
    carryoverPreview: null,
    pendingErrorFlash: null,
    pendingSuccessFlash: null,
    pendingNavigation: null,
    farmLimitBlocked: false,
    ...overrides
  };
}

describe('PlanNewComponent', () => {
  let component: PlanNewComponent;
  let fixture: ComponentFixture<PlanNewComponent>;
  let mockLoadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockCreateUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockFarmsPresenter: { setView: ReturnType<typeof vi.fn> };
  let mockCreatePresenter: { setView: ReturnType<typeof vi.fn> };
  let mockCarryoverUseCase: {
    loadSourcePlans: ReturnType<typeof vi.fn>;
    loadCarryoverPreview: ReturnType<typeof vi.fn>;
    loadSourcePlan: ReturnType<typeof vi.fn>;
  };
  let mockReadinessUseCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockLoadUseCase = { execute: vi.fn() };
    mockCreateUseCase = { execute: vi.fn() };
    mockFarmsPresenter = { setView: vi.fn() };
    mockCreatePresenter = { setView: vi.fn() };
    mockCarryoverUseCase = {
      loadSourcePlans: vi.fn(() => of([])),
      loadCarryoverPreview: vi.fn(() =>
        of({ plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] })
      ),
      loadSourcePlan: vi.fn(() => of(null))
    };
    mockReadinessUseCase = {
      execute: vi.fn(() =>
        of(
          buildPlanCreateReadiness({
            farmId: 1,
            fieldCount: 1,
            hasValidFields: true,
            weatherStatus: 'completed',
            crops: [],
            cropBlueprints: {}
          })
        )
      )
    };

    await TestBed.configureTestingModule({
      imports: [PlanNewComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: LoadPrivatePlanFarmsUseCase, useValue: mockLoadUseCase },
        { provide: CreatePrivatePlanUseCase, useValue: mockCreateUseCase },
        { provide: PlanNewPresenter, useValue: mockFarmsPresenter },
        { provide: CreatePrivatePlanPresenter, useValue: mockCreatePresenter },
        { provide: LoadPlanNewCarryoverUseCase, useValue: mockCarryoverUseCase },
        { provide: LoadPlanNewReadinessUseCase, useValue: mockReadinessUseCase }
      ]
    })
      .overrideComponent(PlanNewComponent, { set: { providers: [] } })
      .compileComponents();

    fixture = TestBed.createComponent(PlanNewComponent);
    component = fixture.componentInstance;

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'plans.index.title': 'Plans',
      'plans.new.breadcrumb': 'New plan',
      'plans.new.title': 'Select a farm',
      'plans.new.subtitle': 'Choose a farm',
      'plans.new.farm_label': 'Farm',
      'plans.new.farm_hint': 'Select a farm',
      'plans.new.farm_option_no_fields': '{{name}} (no fields)',
      'plans.new.no_fields_warning': 'This farm has no registered fields.',
      'plans.new.register_fields_link': 'Register fields',
      'plans.new.some_farms_no_fields_hint':
        'Farms without registered fields cannot be selected for planning.',
      'plans.new.plan_name_label': 'Plan name',
      'plans.new.plan_name_placeholder': 'e.g. Main plan',
      'plans.new.create_button': 'Create',
      'plans.new.farm_limit_blocked': 'You have reached the maximum number of farms (4).',
      'plans.new.farm_limit_blocked_hint':
        'Manage your existing farms or register fields before creating a plan.',
      'plans.new.manage_farms_link': 'Manage farms',
      'plans.new.carryover_enabled_label': 'Carry over previous plan learning data',
      'plans.new.carryover_hint': 'Apply variance learning from a completed plan.',
      'plans.new.carryover_source_label': 'Source plan',
      'plans.new.carryover_source_hint': 'Select a previous plan',
      'plans.new.carryover_preview_title': 'Learning data preview',
      'plans.new.carryover_no_source_plans': 'No previous plans found.',
      'plans.new.carryover_preview_empty': 'No category variance data.',
      'plans.new.carryover_learn_cta': 'Create and review on Learn',
      'plans.carryover.preview.title': 'Learning data preview',
      'plans.carryover.preview.empty': 'No category variance data.',
      'plans.carryover.preview.stage_gdd_count': 'Stage GDD calibration proposals',
      'plans.carryover.preview.bp_timing_count': 'BP timing adjustment proposals',
      'plans.carryover.preview.bp_amount_count': 'BP amount adjustment proposals',
      'plans.task_schedules.variance_subview.category_column': 'Category',
      'plans.task_schedules.variance_subview.category_average': 'Avg Δ days',
      'plans.task_schedules.variance_subview.not_available': '—',
      'plans.task_schedules.variance_subview.average_value': '{{delta}} days',
      'plans.task_schedules.variance_subview.category.general': 'General tasks',
      'plans.learn.proposal_confidence.high': 'High confidence',
      'plans.new.readiness.title': 'Setup readiness',
      'plans.new.readiness.fields_ready': 'Fields registered ({{count}})',
      'plans.new.readiness.weather_ready': 'Weather data ready',
      'plans.new.readiness.crops_missing': 'No crops registered yet',
      'plans.new.readiness.crops_action': 'Set up crops',
      'common.loading': 'Loading...'
    });
    translate.setDefaultLang('en');
    translate.use('en');
  });

  it('should initialize presenters and load farms on init', () => {
    component.ngOnInit();

    expect(mockFarmsPresenter.setView).toHaveBeenCalledWith(component);
    expect(mockCreatePresenter.setView).toHaveBeenCalledWith(component);
    expect(mockLoadUseCase.execute).toHaveBeenCalled();
  });

  it('should call createUseCase on submit when farm has valid fields', () => {
    component.control = defaultControl({
      farms: [{ id: 1, name: 'Farm', fieldCount: 1, totalArea: 50, hasValidFields: true }],
      selectedFarmId: 1
    });
    component.planName = 'My Plan';

    component.onSubmit(new Event('submit'));

    expect(mockCreateUseCase.execute).toHaveBeenCalledWith({
      farmId: 1,
      planName: 'My Plan',
      navigateToLearnAfterCreate: false
    });
  });

  it('includes carryoverFromPlanId on submit when carryover is enabled and source plan selected', () => {
    component.control = defaultControl({
      farms: [{ id: 1, name: 'Farm', fieldCount: 1, totalArea: 50, hasValidFields: true }],
      selectedFarmId: 1,
      carryoverEnabled: true,
      selectedSourcePlanId: 9
    });

    component.onSubmit(new Event('submit'));

    expect(mockCreateUseCase.execute).toHaveBeenCalledWith({
      farmId: 1,
      carryoverFromPlanId: 9,
      navigateToLearnAfterCreate: false
    });
  });

  it('submits with navigateToLearnAfterCreate when learn CTA is clicked', () => {
    component.control = defaultControl({
      farms: [{ id: 1, name: 'Farm', fieldCount: 1, totalArea: 50, hasValidFields: true }],
      selectedFarmId: 1,
      carryoverEnabled: true,
      selectedSourcePlanId: 9,
      carryoverPreview: {
        plan_id: 9,
        unrecorded_count: 0,
        categories: [],
        top_variance_items: []
      }
    });

    component.onSubmitWithLearnReview(new Event('submit'));

    expect(mockCreateUseCase.execute).toHaveBeenCalledWith({
      farmId: 1,
      carryoverFromPlanId: 9,
      navigateToLearnAfterCreate: true
    });
  });

  it('shows learn CTA when carryover preview is available', () => {
    fixture.detectChanges();
    component.control = defaultControl({
      farms: [{ id: 1, name: 'Farm', fieldCount: 1, totalArea: 50, hasValidFields: true }],
      selectedFarmId: 1,
      carryoverEnabled: true,
      sourcePlans: [{ id: 9, name: 'Source', farm_id: 1 }],
      selectedSourcePlanId: 9,
      carryoverPreview: {
        plan_id: 9,
        unrecorded_count: 0,
        categories: [],
        top_variance_items: []
      }
    });
    fixture.detectChanges();

    const cta = fixture.nativeElement.querySelector('.plan-new-carryover-learn-cta');
    expect(cta?.textContent?.trim()).toBe('Create and review on Learn');
  });

  it('loads source plans filtered by farm when carryover is enabled', () => {
    mockCarryoverUseCase.loadSourcePlans.mockReturnValue(
      of([
        { id: 1, name: 'Plan A', farm_id: 10 },
        { id: 3, name: 'Plan C', farm_id: 10 }
      ])
    );

    component.control = defaultControl({ selectedFarmId: 10 });
    component.onCarryoverEnabledChange(true);

    expect(mockCarryoverUseCase.loadSourcePlans).toHaveBeenCalledWith(10);
    expect(component.control.sourcePlans).toEqual([
      { id: 1, name: 'Plan A', farm_id: 10 },
      { id: 3, name: 'Plan C', farm_id: 10 }
    ]);
  });

  it('loads carryover preview when source plan is selected', () => {
    const summary = {
      plan_id: 5,
      unrecorded_count: 0,
      categories: [{ category: 'general', average_delta_days: 2, item_count: 3, recorded_count: 2 }],
      top_variance_items: []
    };
    mockCarryoverUseCase.loadCarryoverPreview.mockReturnValue(of(summary));

    component.onSourcePlanChange(5);

    expect(mockCarryoverUseCase.loadCarryoverPreview).toHaveBeenCalledWith(5);
    expect(component.control.carryoverPreview).toEqual(summary);
    expect(component.control.carryoverPreviewLoading).toBe(false);
  });

  it('renders breadcrumb with plans list link and no bottom cancel button', () => {
    component.control = defaultControl({
      farms: [{ id: 1, name: 'Farm', fieldCount: 1, totalArea: 50, hasValidFields: true }],
      selectedFarmId: 1
    });
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink).toBeTruthy();
    expect(backLink.getAttribute('href')).toBe('/plans');
    expect(backLink.textContent?.trim()).toBe('Plans');

    const current = fixture.nativeElement.querySelector('[aria-current="page"]');
    expect(current?.textContent?.trim()).toBe('New plan');

    const cancelLinks = Array.from(
      fixture.nativeElement.querySelectorAll('a.btn-secondary')
    ) as HTMLAnchorElement[];
    expect(cancelLinks.some((a) => a.getAttribute('href') === '/plans')).toBe(false);
  });

  it('shows plans list breadcrumb while loading', () => {
    component.control = { ...component.control, loading: true };
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink).toBeTruthy();
    expect(backLink.getAttribute('href')).toBe('/plans');
  });

  it('shows no-fields warning and register link before selection when only farms without fields exist', () => {
    fixture.detectChanges();
    component.control = defaultControl({
      farms: [{ id: 42, name: 'Empty Farm', fieldCount: 0, totalArea: 0, hasValidFields: false }]
    });
    fixture.detectChanges();

    const warning = fixture.nativeElement.querySelector('.plan-new-warning');
    expect(warning).toBeTruthy();
    expect(warning?.textContent).toContain('This farm has no registered fields.');

    const registerLink = fixture.nativeElement.querySelector(
      'a.plan-new-warning__link'
    ) as HTMLAnchorElement;
    expect(registerLink).toBeTruthy();
    expect(registerLink.getAttribute('href')).toBe('/farms/42');
    expect(registerLink.textContent?.trim()).toBe('Register fields');
  });

  it('shows summary hint and per-farm register links when some farms lack fields but others are selectable', () => {
    fixture.detectChanges();
    component.control = defaultControl({
      farms: [
        { id: 1, name: 'Ready Farm', fieldCount: 2, totalArea: 100, hasValidFields: true },
        { id: 2, name: 'Empty Farm', fieldCount: 0, totalArea: 0, hasValidFields: false },
        { id: 3, name: 'Another Empty', fieldCount: 0, totalArea: 0, hasValidFields: false }
      ]
    });
    fixture.detectChanges();

    const warnings = fixture.nativeElement.querySelectorAll('.plan-new-warning');
    expect(warnings.length).toBeGreaterThanOrEqual(1);
    expect(warnings[0]?.textContent).toContain(
      'Farms without registered fields cannot be selected for planning.'
    );

    const registerLinks = Array.from(
      fixture.nativeElement.querySelectorAll('a.plan-new-warning__link')
    ) as HTMLAnchorElement[];
    expect(registerLinks).toHaveLength(2);
    expect(registerLinks.map((link) => link.getAttribute('href'))).toEqual(['/farms/2', '/farms/3']);
    expect(registerLinks.every((link) => link.textContent?.trim() === 'Register fields')).toBe(true);

    const farmRows = fixture.nativeElement.querySelectorAll('.plan-new-warning--farm');
    expect(farmRows).toHaveLength(2);
    expect(farmRows[0]?.textContent).toContain('Empty Farm');
    expect(farmRows[1]?.textContent).toContain('Another Empty');
  });

  it('shows farm limit blocked UI with manage farms link instead of create farm CTA', () => {
    fixture.detectChanges();
    component.control = defaultControl({
      farms: [],
      farmLimitBlocked: true
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-new-empty')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain(
      'You have reached the maximum number of farms (4).'
    );
    const manageLink = fixture.nativeElement.querySelector(
      'a.btn-primary'
    ) as HTMLAnchorElement;
    expect(manageLink?.getAttribute('href')).toBe('/farms');
    expect(manageLink?.textContent?.trim()).toBe('Manage farms');
    expect(fixture.nativeElement.textContent).not.toContain('Create Farm');
  });

  it('should not submit when selected farm has no valid fields', () => {
    component.control = defaultControl({
      farms: [{ id: 1, name: 'Farm', fieldCount: 0, totalArea: 0, hasValidFields: false }],
      selectedFarmId: 1,
      noFieldsWarning: true
    });

    component.onSubmit(new Event('submit'));

    expect(mockCreateUseCase.execute).not.toHaveBeenCalled();
  });

  it('renders carryover preview when enabled with source plan selected', () => {
    fixture.detectChanges();
    component.control = defaultControl({
      farms: [{ id: 1, name: 'Farm', fieldCount: 1, totalArea: 50, hasValidFields: true }],
      selectedFarmId: 1,
      carryoverEnabled: true,
      sourcePlans: [{ id: 9, name: 'Old Plan', farm_id: 1 }],
      selectedSourcePlanId: 9,
      carryoverPreview: {
        plan_id: 9,
        unrecorded_count: 0,
        categories: [
          { category: 'general', average_delta_days: 2, item_count: 1, recorded_count: 1 }
        ],
        top_variance_items: []
      }
    });
    fixture.detectChanges();

    expect(component.control.carryoverEnabled).toBe(true);
    expect(
      fixture.nativeElement.querySelector('input[name="carryoverEnabled"]')
    ).toBeTruthy();
    const preview = fixture.nativeElement.querySelector('.plan-carryover-preview');
    expect(preview).toBeTruthy();
    expect(preview?.textContent).toContain('Learning data preview');
    expect(preview?.textContent).toContain('General tasks');
    expect(preview?.textContent).toContain('+2 days');
  });

  it('shows GDD and BP proposal counts in carryover preview table', () => {
    fixture.detectChanges();
    component.control = defaultControl({
      farms: [{ id: 1, name: 'Farm', fieldCount: 1, totalArea: 50, hasValidFields: true }],
      selectedFarmId: 1,
      carryoverEnabled: true,
      sourcePlans: [{ id: 9, name: 'Old Plan', farm_id: 1 }],
      selectedSourcePlanId: 9,
      carryoverPreview: {
        plan_id: 9,
        unrecorded_count: 0,
        categories: [],
        stage_gdd_calibration_proposals: [{ crop_id: 1, stage_id: 2 } as never],
        blueprint_amount_adjustment_proposals: [
          { crop_id: 1, category: 'general', stage_order: 1 } as never
        ],
        top_variance_items: []
      }
    });
    fixture.detectChanges();

    const rows = fixture.nativeElement.querySelectorAll('.plan-carryover-preview__table tbody tr');
    expect(rows).toHaveLength(2);
    expect(rows[0].textContent).toContain('Stage GDD calibration proposals');
    expect(rows[1].textContent).toContain('BP amount adjustment proposals');
  });

  it('loads and shows readiness summary after farm selection', () => {
    fixture.detectChanges();
    component.control = defaultControl({
      farms: [{ id: 1, name: 'Farm', fieldCount: 1, totalArea: 50, hasValidFields: true }]
    });
    component.onFarmChange(1);
    fixture.detectChanges();

    expect(mockReadinessUseCase.execute).toHaveBeenCalledWith(1, 1, true);
    expect(fixture.nativeElement.querySelector('.plan-create-readiness')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Setup readiness');
    expect(fixture.nativeElement.textContent).toContain('Fields registered (1)');
  });

  it('presets carryover from carryoverFrom query param after farms load', () => {
    const sourcePlan = { id: 7, name: 'Source Plan', farm_id: 10 };
    mockCarryoverUseCase.loadSourcePlan = vi.fn(() => of(sourcePlan));
    mockCarryoverUseCase.loadSourcePlans.mockReturnValue(of([sourcePlan]));
    mockCarryoverUseCase.loadCarryoverPreview.mockReturnValue(
      of({
        plan_id: 7,
        unrecorded_count: 0,
        categories: [],
        top_variance_items: []
      })
    );

    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      imports: [PlanNewComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: { queryParamMap: { get: (key: string) => (key === 'carryoverFrom' ? '7' : null) } }
          }
        },
        { provide: LoadPrivatePlanFarmsUseCase, useValue: mockLoadUseCase },
        { provide: CreatePrivatePlanUseCase, useValue: mockCreateUseCase },
        { provide: PlanNewPresenter, useValue: mockFarmsPresenter },
        { provide: CreatePrivatePlanPresenter, useValue: mockCreatePresenter },
        { provide: LoadPlanNewCarryoverUseCase, useValue: mockCarryoverUseCase },
        { provide: LoadPlanNewReadinessUseCase, useValue: mockReadinessUseCase }
      ]
    })
      .overrideComponent(PlanNewComponent, { set: { providers: [] } })
      .compileComponents();

    const localFixture = TestBed.createComponent(PlanNewComponent);
    const localComponent = localFixture.componentInstance;
    localComponent.control = defaultControl({
      farms: [{ id: 10, name: 'Farm', fieldCount: 1, totalArea: 50, hasValidFields: true }]
    });

    localComponent.applyCarryoverFromQueryPreset();

    expect(mockCarryoverUseCase.loadSourcePlan).toHaveBeenCalledWith(7);
    expect(localComponent.control.carryoverEnabled).toBe(true);
    expect(localComponent.control.selectedFarmId).toBe(10);
    expect(localComponent.control.selectedSourcePlanId).toBe(7);
  });
});
