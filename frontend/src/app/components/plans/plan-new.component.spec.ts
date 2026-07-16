import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { provideRouter } from '@angular/router';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PlanNewComponent } from './plan-new.component';
import { LoadPrivatePlanFarmsUseCase } from '../../usecase/private-plan-create/load-private-plan-farms.usecase';
import { CreatePrivatePlanUseCase } from '../../usecase/private-plan-create/create-private-plan.usecase';
import { PlanNewPresenter } from '../../usecase/plans/plan-new.providers';
import { CreatePrivatePlanPresenter } from '../../adapters/private-plan-create/create-private-plan.presenter';

describe('PlanNewComponent', () => {
  let component: PlanNewComponent;
  let fixture: ComponentFixture<PlanNewComponent>;
  let mockLoadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockCreateUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockFarmsPresenter: { setView: ReturnType<typeof vi.fn> };
  let mockCreatePresenter: { setView: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockLoadUseCase = { execute: vi.fn() };
    mockCreateUseCase = { execute: vi.fn() };
    mockFarmsPresenter = { setView: vi.fn() };
    mockCreatePresenter = { setView: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [PlanNewComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: LoadPrivatePlanFarmsUseCase, useValue: mockLoadUseCase },
        { provide: CreatePrivatePlanUseCase, useValue: mockCreateUseCase },
        { provide: PlanNewPresenter, useValue: mockFarmsPresenter },
        { provide: CreatePrivatePlanPresenter, useValue: mockCreatePresenter }
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
    component.control = {
      loading: false,
      submitting: false,
      error: null,
      farms: [{ id: 1, name: 'Farm', fieldCount: 1, totalArea: 50, hasValidFields: true }],
      selectedFarmId: 1,
      noFieldsWarning: false,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      pendingNavigation: null
    };
    component.planName = 'My Plan';

    component.onSubmit(new Event('submit'));

    expect(mockCreateUseCase.execute).toHaveBeenCalledWith({
      farmId: 1,
      planName: 'My Plan'
    });
  });

  it('renders breadcrumb with plans list link and no bottom cancel button', () => {
    component.control = {
      loading: false,
      submitting: false,
      error: null,
      farms: [{ id: 1, name: 'Farm', fieldCount: 1, totalArea: 50, hasValidFields: true }],
      selectedFarmId: 1,
      noFieldsWarning: false,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      pendingNavigation: null
    };
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
    component.control = {
      loading: false,
      submitting: false,
      error: null,
      farms: [{ id: 42, name: 'Empty Farm', fieldCount: 0, totalArea: 0, hasValidFields: false }],
      selectedFarmId: null,
      noFieldsWarning: false,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      pendingNavigation: null
    };
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
    component.control = {
      loading: false,
      submitting: false,
      error: null,
      farms: [
        { id: 1, name: 'Ready Farm', fieldCount: 2, totalArea: 100, hasValidFields: true },
        { id: 2, name: 'Empty Farm', fieldCount: 0, totalArea: 0, hasValidFields: false },
        { id: 3, name: 'Another Empty', fieldCount: 0, totalArea: 0, hasValidFields: false }
      ],
      selectedFarmId: null,
      noFieldsWarning: false,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      pendingNavigation: null
    };
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

  it('should not submit when selected farm has no valid fields', () => {
    component.control = {
      loading: false,
      submitting: false,
      error: null,
      farms: [{ id: 1, name: 'Farm', fieldCount: 0, totalArea: 0, hasValidFields: false }],
      selectedFarmId: 1,
      noFieldsWarning: true,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      pendingNavigation: null
    };

    component.onSubmit(new Event('submit'));

    expect(mockCreateUseCase.execute).not.toHaveBeenCalled();
  });
});
