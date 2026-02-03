import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PublicPlanResultsComponent } from './public-plan-results.component';
import { SavePublicPlanUseCase } from '../../usecase/public-plans/save-public-plan.usecase';
import { LoadPublicPlanResultsUseCase } from '../../usecase/public-plans/load-public-plan-results.usecase';
import { PublicPlanResultsPresenter } from '../../adapters/public-plans/public-plan-results.presenter';
import { LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT } from '../../usecase/public-plans/load-public-plan-results.output-port';
import { SAVE_PUBLIC_PLAN_OUTPUT_PORT } from '../../usecase/public-plans/save-public-plan.output-port';
import { PublicPlanResultsViewState } from './public-plan-results.view';
import { AuthService } from '../../services/auth.service';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { ChangeDetectorRef } from '@angular/core';

describe('PublicPlanResultsComponent', () => {
  let component: PublicPlanResultsComponent;
  let fixture: ComponentFixture<PublicPlanResultsComponent>;
  let saveUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let authService: { user: ReturnType<typeof vi.fn> };
  let publicPlanStore: { state: { planId: number | null; farm: any } };
  let activatedRoute: { snapshot: { queryParamMap: { get: ReturnType<typeof vi.fn> } } };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    saveUseCase = { execute: vi.fn(() => of(undefined)) };
    loadUseCase = { execute: vi.fn(() => of(undefined)) };
    mockPresenter = { setView: vi.fn() };
    authService = { user: vi.fn() };
    publicPlanStore = { state: { planId: null, farm: { name: 'Test Farm' } } };
    activatedRoute = {
      snapshot: {
        queryParamMap: { get: vi.fn() }
      }
    };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(PublicPlanResultsComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPublicPlanResultsUseCase, useValue: loadUseCase },
          { provide: SavePublicPlanUseCase, useValue: saveUseCase },
          { provide: PublicPlanResultsPresenter, useValue: mockPresenter },
          { provide: LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT, useValue: mockPresenter },
          { provide: SAVE_PUBLIC_PLAN_OUTPUT_PORT, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PublicPlanResultsComponent, TranslateModule.forRoot()],
      providers: [
        { provide: ActivatedRoute, useValue: activatedRoute },
        { provide: AuthService, useValue: authService },
        { provide: PublicPlanStore, useValue: publicPlanStore }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(PublicPlanResultsComponent);
    component = fixture.componentInstance;
  });

  it('implements View control getter/setter', () => {
    const state: PublicPlanResultsViewState = {
      loading: false,
      error: null,
      data: null
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  describe('savePlan', () => {
    beforeEach(() => {
      // Mock window.location.href
      Object.defineProperty(window, 'location', {
        value: { href: 'http://localhost:4200/public-plans/results?planId=123' },
        writable: true
      });
    });

    it('redirects to login when user is not authenticated', () => {
      authService.user.mockReturnValue(null);
      activatedRoute.snapshot.queryParamMap.get.mockReturnValue('123');

      const originalLocation = window.location.href;
      component.savePlan();

      expect(window.location.href).toContain('/auth/login?return_to=');
      expect(saveUseCase.execute).not.toHaveBeenCalled();
    });

    it('calls saveUseCase.execute with planId from query params when user is authenticated', () => {
      authService.user.mockReturnValue({ id: 1, name: 'Test User' });
      activatedRoute.snapshot.queryParamMap.get.mockReturnValue('123');

      component.savePlan();

      expect(saveUseCase.execute).toHaveBeenCalledWith({ planId: 123 });
    });

    it('calls saveUseCase.execute with planId from store when query param is not available', () => {
      authService.user.mockReturnValue({ id: 1, name: 'Test User' });
      activatedRoute.snapshot.queryParamMap.get.mockReturnValue(null);
      publicPlanStore.state.planId = 456;

      component.savePlan();

      expect(saveUseCase.execute).toHaveBeenCalledWith({ planId: 456 });
    });

    it('does not call saveUseCase.execute when planId is not available', () => {
      authService.user.mockReturnValue({ id: 1, name: 'Test User' });
      activatedRoute.snapshot.queryParamMap.get.mockReturnValue(null);
      publicPlanStore.state.planId = null;

      component.savePlan();

      expect(saveUseCase.execute).not.toHaveBeenCalled();
    });
  });

  describe('climate panel interactions', () => {
    it('opens the climate panel for a new cultivation selection', () => {
      component.handleCultivationSelection({ cultivationId: 5, planType: 'public' });

      expect(component.selectedCultivationId).toBe(5);
      expect(component.selectedPlanType).toBe('public');
    });

    it('closes the climate panel when the same cultivation is selected again', () => {
      component.selectedCultivationId = 5;
      component.selectedPlanType = 'public';

      component.handleCultivationSelection({ cultivationId: 5, planType: 'public' });

      expect(component.selectedCultivationId).toBeNull();
      expect(component.selectedPlanType).toBe('public');
    });

    it('resets selection via closeClimatePanel', () => {
      component.selectedCultivationId = 8;
      component.selectedPlanType = 'private';

      component.closeClimatePanel();

      expect(component.selectedCultivationId).toBeNull();
      expect(component.selectedPlanType).toBe('public');
    });
  });
});
