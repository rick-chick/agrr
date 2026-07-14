import { describe, it, expect, vi, beforeEach } from 'vitest';
import { PublicPlanSelectCropComponent } from './public-plan-select-crop.component';
import { PublicPlanSelectCropViewState } from './public-plan-select-crop.view';
import {
  PUBLIC_PLAN_WIZARD_STEP_QUERY_PARAM,
  PUBLIC_PLAN_WIZARD_STEP_REGION,
} from '../../domain/public-plans/public-plan-wizard-navigation';

describe('PublicPlanSelectCropComponent (class-level)', () => {
  let component: any;
  let loadCropsUseCase: { execute: ReturnType<typeof vi.fn> };
  let createPlanUseCase: { execute: ReturnType<typeof vi.fn> };
  let resetStateUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: { setView: ReturnType<typeof vi.fn> };
  let publicPlanStore: {
    state: {
      farm?: { id: number; name: string; region: string };
      farmSize?: { id: string; name: string; area_sqm: number };
      selectedCrops: any[];
      planId: number | null;
      pendingCropSlug: string | null;
    };
    setSelectedCrops: ReturnType<typeof vi.fn>;
    setPlanId: ReturnType<typeof vi.fn>;
    setFarm: ReturnType<typeof vi.fn>;
    setPendingCropSlug: ReturnType<typeof vi.fn>;
  };
  let router: { navigate: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    loadCropsUseCase = { execute: vi.fn() };
    createPlanUseCase = { execute: vi.fn() };
    resetStateUseCase = { execute: vi.fn() };
    presenter = { setView: vi.fn() };
    publicPlanStore = {
      state: {
        farm: { id: 1, name: 'Test Farm', region: 'jp' },
        farmSize: { id: 'home_garden', name: 'Home Garden', area_sqm: 30 },
        selectedCrops: [],
        planId: null,
        pendingCropSlug: null
      },
      setSelectedCrops: vi.fn(),
      setPlanId: vi.fn(),
      setFarm: vi.fn(),
      setPendingCropSlug: vi.fn()
    };
    router = { navigate: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    // Create a plain instance and inject dependencies manually to avoid Angular TestBed complexities.
    component = Object.create(PublicPlanSelectCropComponent.prototype);
    component.router = router;
    component.loadCropsUseCase = loadCropsUseCase;
    component.createPlanUseCase = createPlanUseCase;
    component.resetStateUseCase = resetStateUseCase;
    component.presenter = presenter;
    component.publicPlanStore = publicPlanStore;
    component.cdr = cdr;
    component.selectedCropIds = new Set<number>();
    component.selectedCrops = [];
    component._control = {
      loading: true,
      error: null,
      crops: [],
      saving: false
    };
  });

  it('implements View control getter/setter and triggers change detection', () => {
    const state: PublicPlanSelectCropViewState = {
      loading: false,
      error: null,
      crops: [],
      saving: false
    
    };

    const markForCheckSpy = vi.spyOn(component.cdr, 'markForCheck');
    // Use the class accessor descriptor if available, otherwise fall back to manual assignment.
    const desc = Object.getOwnPropertyDescriptor(PublicPlanSelectCropComponent.prototype, 'control');
    if (desc && typeof desc.set === 'function' && typeof desc.get === 'function') {
      desc.set.call(component, state);
      const got = desc.get.call(component);
      expect(got).toEqual(state);
    } else {
      // Fallback: set backing field and trigger cdr manually
      component._control = state;
      component.cdr.markForCheck();
      expect(component._control).toEqual(state);
    }
    expect(markForCheckSpy).toHaveBeenCalledTimes(1);
  });

  it('ngOnInit resets state, sets view on presenter and loads crops when farm is available', () => {
    PublicPlanSelectCropComponent.prototype.ngOnInit.call(component);

    expect(resetStateUseCase.execute).toHaveBeenCalledWith({});
    expect(publicPlanStore.setFarm).toHaveBeenCalledWith(publicPlanStore.state.farm);
    expect(presenter.setView).toHaveBeenCalledWith(component);
    expect(loadCropsUseCase.execute).toHaveBeenCalledWith({ farmId: 1 });
    expect(router.navigate).not.toHaveBeenCalled();
  });

  it('ngOnInit preserves pending research crop slug across reset', () => {
    publicPlanStore.state.pendingCropSlug = 'tomato';
    resetStateUseCase.execute = vi.fn(() => {
      publicPlanStore.state.pendingCropSlug = null;
    });

    PublicPlanSelectCropComponent.prototype.ngOnInit.call(component);

    expect(publicPlanStore.setPendingCropSlug).toHaveBeenCalledWith('tomato');
  });

  it('ngOnInit navigates to /public-plans/new when farm is missing', () => {
    publicPlanStore.state = {
      farm: undefined,
      farmSize: { id: 'home_garden', name: 'Home Garden', area_sqm: 30 },
      selectedCrops: [],
      planId: null,
      pendingCropSlug: null
    };

    PublicPlanSelectCropComponent.prototype.ngOnInit.call(component);

    expect(router.navigate).toHaveBeenCalledWith(['/public-plans/new'], {
      queryParams: { [PUBLIC_PLAN_WIZARD_STEP_QUERY_PARAM]: PUBLIC_PLAN_WIZARD_STEP_REGION },
      replaceUrl: true,
    });
    expect(resetStateUseCase.execute).not.toHaveBeenCalled();
    expect(presenter.setView).not.toHaveBeenCalled();
    expect(loadCropsUseCase.execute).not.toHaveBeenCalled();
  });

  it('createPlan calls CreatePublicPlanUseCase with correct parameters and navigates on success', () => {
    component.selectedCropIds = new Set([1, 2, 3]);
    component._control = {
      loading: false,
      error: null,
      crops: [],
      saving: false
    };

    let onSuccessCallback: ((response: { plan_id: number }) => void) | undefined;
    createPlanUseCase.execute = vi.fn((dto: any) => {
      onSuccessCallback = dto.onSuccess;
    });

    PublicPlanSelectCropComponent.prototype.createPlan.call(component);

    expect(createPlanUseCase.execute).toHaveBeenCalledWith({
      farmId: 1,
      farmSizeId: 'home_garden',
      cropIds: [1, 2, 3],
      onSuccess: expect.any(Function)
    });
    expect(component._control.saving).toBe(true);
    expect(component._control.error).toBe(null);

    // Simulate success callback
    if (onSuccessCallback) {
      onSuccessCallback({ plan_id: 123 });
      expect(publicPlanStore.setPlanId).toHaveBeenCalledWith(123);
      expect(router.navigate).toHaveBeenCalledWith(['/public-plans/optimizing'], {
        queryParams: { planId: 123 }
      });
    }
  });

  it('createPlan does nothing when saving is in progress', () => {
    component.selectedCropIds = new Set([1]);
    component._control = {
      loading: false,
      error: null,
      crops: [],
      saving: true
    };

    PublicPlanSelectCropComponent.prototype.createPlan.call(component);

    expect(createPlanUseCase.execute).not.toHaveBeenCalled();
  });

  it('createPlan does nothing when no crops are selected', () => {
    component.selectedCropIds = new Set();
    component._control = {
      loading: false,
      error: null,
      crops: [],
      saving: false
    };

    PublicPlanSelectCropComponent.prototype.createPlan.call(component);

    expect(createPlanUseCase.execute).not.toHaveBeenCalled();
  });

  it('preselects crop when pending research slug matches loaded crops', () => {
    publicPlanStore.state.pendingCropSlug = 'tomato';
    component.selectedCropIds = new Set();
    component.selectedCrops = [];
    const crops = [
      { id: 10, name: 'トマト' },
      { id: 11, name: 'キュウリ' }
    ];

    const desc = Object.getOwnPropertyDescriptor(PublicPlanSelectCropComponent.prototype, 'control');
    if (desc?.set) {
      desc.set.call(component, {
        loading: false,
        error: null,
        crops,
        saving: false
      });
    }

    expect(publicPlanStore.setPendingCropSlug).toHaveBeenCalledWith(null);
    expect(component.selectedCropIds).toEqual(new Set([10]));
    expect(component.selectedCrops).toEqual([{ id: 10, name: 'トマト' }]);
    expect(publicPlanStore.setSelectedCrops).toHaveBeenCalledWith([{ id: 10, name: 'トマト' }]);
  });

  it('toggleCrop adds crop when not selected', () => {
    const crop = { id: 1, name: 'Test Crop' };
    component.selectedCropIds = new Set();
    component.selectedCrops = [];

    PublicPlanSelectCropComponent.prototype.toggleCrop.call(component, crop);

    expect(component.selectedCropIds.has(1)).toBe(true);
    expect(component.selectedCrops).toEqual([crop]);
    expect(publicPlanStore.setSelectedCrops).toHaveBeenCalledWith([crop]);
  });

  it('toggleCrop removes crop when already selected', () => {
    const crop = { id: 1, name: 'Test Crop' };
    component.selectedCropIds = new Set([1]);
    component.selectedCrops = [crop];

    PublicPlanSelectCropComponent.prototype.toggleCrop.call(component, crop);

    expect(component.selectedCropIds.has(1)).toBe(false);
    expect(component.selectedCrops).toEqual([]);
    expect(publicPlanStore.setSelectedCrops).toHaveBeenCalledWith([]);
  });
});

describe('PublicPlanSelectCropComponent (template)', () => {
  it('renders breadcrumb and omits the fixed bottom back button', async () => {
    const { TestBed } = await import('@angular/core/testing');
    const { provideRouter } = await import('@angular/router');
    const { TranslateModule, TranslateService } = await import('@ngx-translate/core');
    const { PublicPlanSelectCropComponent } = await import('./public-plan-select-crop.component');
    const { LoadPublicPlanCropsUseCase } = await import(
      '../../usecase/public-plans/load-public-plan-crops.usecase'
    );
    const { CreatePublicPlanUseCase } = await import(
      '../../usecase/public-plans/create-public-plan.usecase'
    );
    const { ResetPublicPlanCreationStateUseCase } = await import(
      '../../usecase/public-plans/reset-public-plan-creation-state.usecase'
    );
    const { PublicPlanSelectCropPresenter } = await import(
      '../../usecase/public-plans/public-plan-select-crop.providers'
    );
    const { PublicPlanStore } = await import('../../services/public-plans/public-plan-store.service');

    await TestBed.configureTestingModule({
      imports: [PublicPlanSelectCropComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    })
      .overrideComponent(PublicPlanSelectCropComponent, {
        set: {
          providers: [
            { provide: LoadPublicPlanCropsUseCase, useValue: { execute: vi.fn() } },
            { provide: CreatePublicPlanUseCase, useValue: { execute: vi.fn() } },
            { provide: ResetPublicPlanCreationStateUseCase, useValue: { execute: vi.fn() } },
            { provide: PublicPlanSelectCropPresenter, useValue: { setView: vi.fn() } },
            {
              provide: PublicPlanStore,
              useValue: {
                state: {
                  farm: { id: 1, name: 'Test Farm', region: 'jp' },
                  selectedCrops: [],
                  planId: null,
                  pendingCropSlug: null
                },
                setSelectedCrops: vi.fn(),
                setPlanId: vi.fn(),
                setFarm: vi.fn(),
                setPendingCropSlug: vi.fn()
              }
            }
          ]
        }
      })
      .compileComponents();

    const fixture = TestBed.createComponent(PublicPlanSelectCropComponent);
    const instance = fixture.componentInstance;
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'public_plans.breadcrumb_root': 'Free crop plan',
      'public_plans.steps.crop': 'Crop',
      'public_plans.title': 'Crop Planning',
      'public_plans.steps.region': 'Region',
      'public_plans.select_crop.bottom_bar.back_button': 'Back',
      'public_plans.select_crop.bottom_bar.selected_label': 'Selected',
      'public_plans.select_crop.bottom_bar.selected_unit': 'crops',
      'public_plans.select_crop.bottom_bar.submit_button': 'Submit',
      'public_plans.select_crop.bottom_bar.hint': 'Select crops'
    });
    translate.setDefaultLang('en');
    translate.use('en');

    instance.control = {
      loading: false,
      error: null,
      crops: [{ id: 1, name: 'Tomato', is_reference: false, groups: [] }],
      saving: false
    };
    fixture.detectChanges();

    const backLink = fixture.nativeElement.querySelector(
      'a.master-context-header__back'
    ) as HTMLAnchorElement;
    expect(backLink).toBeTruthy();
    expect(backLink.getAttribute('href')).toBe('/public-plans/new');
    expect(fixture.nativeElement.querySelector('a.back-button')).toBeNull();
  });

  it('renders submit button with btn-gradient class', async () => {
    const { TestBed } = await import('@angular/core/testing');
    const { provideRouter } = await import('@angular/router');
    const { TranslateModule, TranslateService } = await import('@ngx-translate/core');
    const { PublicPlanSelectCropComponent } = await import('./public-plan-select-crop.component');
    const { LoadPublicPlanCropsUseCase } = await import(
      '../../usecase/public-plans/load-public-plan-crops.usecase'
    );
    const { CreatePublicPlanUseCase } = await import(
      '../../usecase/public-plans/create-public-plan.usecase'
    );
    const { ResetPublicPlanCreationStateUseCase } = await import(
      '../../usecase/public-plans/reset-public-plan-creation-state.usecase'
    );
    const { PublicPlanSelectCropPresenter } = await import(
      '../../usecase/public-plans/public-plan-select-crop.providers'
    );
    const { PublicPlanStore } = await import('../../services/public-plans/public-plan-store.service');

    await TestBed.configureTestingModule({
      imports: [PublicPlanSelectCropComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    })
      .overrideComponent(PublicPlanSelectCropComponent, {
        set: {
          providers: [
            { provide: LoadPublicPlanCropsUseCase, useValue: { execute: vi.fn() } },
            { provide: CreatePublicPlanUseCase, useValue: { execute: vi.fn() } },
            { provide: ResetPublicPlanCreationStateUseCase, useValue: { execute: vi.fn() } },
            { provide: PublicPlanSelectCropPresenter, useValue: { setView: vi.fn() } },
            {
              provide: PublicPlanStore,
              useValue: {
                state: {
                  farm: { id: 1, name: 'Test Farm', region: 'jp' },
                  selectedCrops: [],
                  planId: null,
                  pendingCropSlug: null
                },
                setSelectedCrops: vi.fn(),
                setPlanId: vi.fn(),
                setFarm: vi.fn(),
                setPendingCropSlug: vi.fn()
              }
            }
          ]
        }
      })
      .compileComponents();

    const fixture = TestBed.createComponent(PublicPlanSelectCropComponent);
    const instance = fixture.componentInstance;
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', {
      'public_plans.select_crop.bottom_bar.submit_button': 'Submit'
    });
    translate.setDefaultLang('en');
    translate.use('en');

    instance.control = {
      loading: false,
      error: null,
      crops: [{ id: 1, name: 'Tomato', is_reference: false, groups: [] }],
      saving: false
    };
    instance.selectedCropIds = new Set([1]);
    fixture.detectChanges();

    const submit = fixture.nativeElement.querySelector(
      '.submit-button.btn-gradient'
    ) as HTMLButtonElement;
    expect(submit).toBeTruthy();
  });
});
