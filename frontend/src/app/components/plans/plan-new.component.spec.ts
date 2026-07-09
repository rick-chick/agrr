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
      'common.loading': 'Loading...',
      'common.cancel': 'Cancel'
    });
    translate.setDefaultLang('en');
    translate.use('en');
  });

  it('should create', () => {
    expect(component).toBeTruthy();
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
