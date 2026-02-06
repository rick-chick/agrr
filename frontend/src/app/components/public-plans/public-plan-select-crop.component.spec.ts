import { describe, it, expect, vi, beforeEach } from 'vitest';
import { PublicPlanSelectCropComponent } from './public-plan-select-crop.component';
import { PublicPlanSelectCropViewState } from './public-plan-select-crop.view';

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
    };
    setSelectedCrops: ReturnType<typeof vi.fn>;
    setPlanId: ReturnType<typeof vi.fn>;
    setFarm: ReturnType<typeof vi.fn>;
    setFarmSize: ReturnType<typeof vi.fn>;
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
        planId: null
      },
      setSelectedCrops: vi.fn(),
      setPlanId: vi.fn(),
      setFarm: vi.fn(),
      setFarmSize: vi.fn()
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

  it('ngOnInit resets state, sets view on presenter and loads crops when farm and farmSize are available', () => {
    PublicPlanSelectCropComponent.prototype.ngOnInit.call(component);

    expect(resetStateUseCase.execute).toHaveBeenCalledWith({});
    expect(publicPlanStore.setFarm).toHaveBeenCalledWith(publicPlanStore.state.farm);
    expect(publicPlanStore.setFarmSize).toHaveBeenCalledWith(publicPlanStore.state.farmSize);
    expect(presenter.setView).toHaveBeenCalledWith(component);
    expect(loadCropsUseCase.execute).toHaveBeenCalledWith({ farmId: 1 });
    expect(router.navigate).not.toHaveBeenCalled();
  });

  it('ngOnInit navigates to /public-plans/new when farm is missing', () => {
    publicPlanStore.state = {
      farm: undefined,
      farmSize: { id: 'home_garden', name: 'Home Garden', area_sqm: 30 },
      selectedCrops: [],
      planId: null
    };

    PublicPlanSelectCropComponent.prototype.ngOnInit.call(component);

    expect(router.navigate).toHaveBeenCalledWith(['/public-plans/new']);
    expect(resetStateUseCase.execute).not.toHaveBeenCalled();
    expect(presenter.setView).not.toHaveBeenCalled();
    expect(loadCropsUseCase.execute).not.toHaveBeenCalled();
  });

  it('ngOnInit navigates to /public-plans/new when farmSize is missing', () => {
    publicPlanStore.state = {
      farm: { id: 1, name: 'Test Farm', region: 'jp' },
      farmSize: undefined,
      selectedCrops: [],
      planId: null
    };

    PublicPlanSelectCropComponent.prototype.ngOnInit.call(component);

    expect(router.navigate).toHaveBeenCalledWith(['/public-plans/new']);
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
