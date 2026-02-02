import { TestBed } from '@angular/core/testing';
import { ChangeDetectorRef } from '@angular/core';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { TranslateModule } from '@ngx-translate/core';
import { Router } from '@angular/router';
import { PublicPlanCreateComponent } from './public-plan-create.component';
import { LoadPublicPlanFarmsUseCase } from '../../usecase/public-plans/load-public-plan-farms.usecase';
import { PublicPlanCreatePresenter } from '../../adapters/public-plans/public-plan-create.presenter';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { PublicPlanCreateViewState } from './public-plan-create.view';

describe('PublicPlanCreateComponent', () => {
  let component: PublicPlanCreateComponent;
  let useCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: { setView: ReturnType<typeof vi.fn> };
  let publicPlanStore: { state: { farm?: { id: number; region: string } }; setFarm: ReturnType<typeof vi.fn> };
  let cdr: { detectChanges: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    useCase = { execute: vi.fn() };
    presenter = { setView: vi.fn() };
    publicPlanStore = { state: {}, setFarm: vi.fn() };
    cdr = { detectChanges: vi.fn() };

    // Override component-level providers so the component uses our mocks
    TestBed.overrideProvider(LoadPublicPlanFarmsUseCase, { useValue: useCase });
    TestBed.overrideProvider(PublicPlanCreatePresenter, { useValue: presenter });

    await TestBed.configureTestingModule({
      imports: [PublicPlanCreateComponent, TranslateModule.forRoot()],
      providers: [
        { provide: PublicPlanStore, useValue: publicPlanStore },
        { provide: ChangeDetectorRef, useValue: cdr },
        { provide: Router, useValue: { navigate: vi.fn() } }
      ]
    }).compileComponents();

    component = TestBed.createComponent(PublicPlanCreateComponent).componentInstance;
  });

  it('implements View control getter/setter and triggers change detection', () => {
    const state: PublicPlanCreateViewState = {
      loading: false,
      error: null,
      farms: [],
      farmSizes: []
    };

    // Spy on the actual component ChangeDetectorRef to ensure setter triggers change detection
    const detectSpy = vi.spyOn((component as any).cdr, 'detectChanges');

    component.control = state;

    expect(component.control).toEqual(state);
    expect(detectSpy).toHaveBeenCalledTimes(1);
  });

  it('ngOnInit sets view on presenter and restores selected farm', () => {
    publicPlanStore.state = { farm: { id: 12, region: 'jp' } };

    component.ngOnInit();

    expect(presenter.setView).toHaveBeenCalledWith(component);
    expect(component.selectedFarmId).toBe(12);
    expect(component.selectedRegionId).toBe('jp');
    expect(useCase.execute).toHaveBeenCalledWith({ region: 'jp' });
  });

  it('selectRegion triggers loading state and delegates to useCase', () => {
    component.control = {
      loading: false,
      error: null,
      farms: [{ id: 1, name: 'Farm', region: 'jp', latitude: 0, longitude: 0 }],
      farmSizes: []
    };

    component.selectRegion({
      id: 'us',
      name: 'public_plans.regions.us.name',
      description: 'public_plans.regions.us.description',
      icon: '🇺🇸'
    });

    expect(component.selectedRegionId).toBe('us');
    expect(component.control.loading).toBe(true);
    expect(component.control.farms).toEqual([]);
    expect(useCase.execute).toHaveBeenCalledWith({ region: 'us' });
  });
});