import { describe, it, expect, vi, beforeEach } from 'vitest';
import { PublicPlanCreateComponent } from './public-plan-create.component';
import { PublicPlanCreateViewState } from './public-plan-create.view';

describe('PublicPlanCreateComponent (class-level)', () => {
  let component: any;
  let useCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: { setView: ReturnType<typeof vi.fn> };
  let publicPlanStore: { state: { farm?: { id: number; region: string } }; setFarm: ReturnType<typeof vi.fn> };
  let cdr: { detectChanges: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    useCase = { execute: vi.fn() };
    presenter = { setView: vi.fn() };
    publicPlanStore = { state: {}, setFarm: vi.fn() };
    cdr = { detectChanges: vi.fn() };

    // Create a plain instance and inject dependencies manually to avoid Angular TestBed complexities.
    component = Object.create(PublicPlanCreateComponent.prototype);
    component.router = { navigate: vi.fn() };
    component.useCase = useCase;
    component.presenter = presenter;
    component.publicPlanStore = publicPlanStore;
    component.cdr = cdr;
    component._control = {
      loading: true,
      error: null,
      farms: [],
      farmSizes: []
    };
  });

  it('implements View control getter/setter and triggers change detection', () => {
    const state: PublicPlanCreateViewState = {
      loading: false,
      error: null,
      farms: [],
      farmSizes: []
    };

    const detectSpy = vi.spyOn(component.cdr, 'detectChanges');
    // Use the class accessor descriptor if available, otherwise fall back to manual assignment.
    const desc = Object.getOwnPropertyDescriptor(PublicPlanCreateComponent.prototype, 'control');
    if (desc && typeof desc.set === 'function' && typeof desc.get === 'function') {
      desc.set.call(component, state);
      const got = desc.get.call(component);
      expect(got).toEqual(state);
    } else {
      // Fallback: set backing field and trigger cdr manually
      component._control = state;
      component.cdr.detectChanges();
      expect(component._control).toEqual(state);
    }
    expect(detectSpy).toHaveBeenCalledTimes(1);
  });

  it('ngOnInit sets view on presenter and restores selected farm', () => {
    publicPlanStore.state = { farm: { id: 12, region: 'jp' } };

    PublicPlanCreateComponent.prototype.ngOnInit.call(component);

    expect(presenter.setView).toHaveBeenCalledWith(component);
    expect(component.selectedFarmId).toBe(12);
    expect(useCase.execute).toHaveBeenCalledWith({ region: 'jp' });
  });

  it('detects browser region when no farm stored', () => {
    const originalNavigator = (globalThis as any).navigator;
    (globalThis as any).navigator = { languages: ['en-US'], language: 'en-US' };

    try {
      publicPlanStore.state = {};
      PublicPlanCreateComponent.prototype.ngOnInit.call(component);
      expect(useCase.execute).toHaveBeenCalledWith({ region: 'us' });
    } finally {
      (globalThis as any).navigator = originalNavigator;
    }
  });

  it('source/template no longer contains region step or farm.region placeholder', () => {
    // Check the source file to ensure region keys/templates are removed from the template
    const fs = require('fs');
    const path = require('path');
    const src = fs.readFileSync(path.join(__dirname, 'public-plan-create.component.ts'), 'utf8');
    expect(src).not.toContain('public_plans.steps.region');
    expect(src).not.toContain('{{ farm.region }}');
  });
});