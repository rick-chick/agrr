import { Component, ComponentFixture, Input } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
import { ChangeDetectorRef } from '@angular/core';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { PublicPlanResultsComponent } from './public-plan-results.component';
import { PlanGanttClimateShellComponent } from '../plans/plan-gantt-climate-shell.component';
import { PublicPlanContextHeaderComponent } from './public-plan-context-header.component';
import { SavePublicPlanUseCase } from '../../usecase/public-plans/save-public-plan.usecase';
import { LoadPublicPlanResultsUseCase } from '../../usecase/public-plans/load-public-plan-results.usecase';
import { PublicPlanResultsPresenter } from '../../usecase/public-plans/public-plan-results.providers';
import { PublicPlanResultsViewState } from './public-plan-results.view';
import { AuthService } from '../../services/auth.service';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { FlashMessageService } from '../../services/flash-message.service';

@Component({
  selector: 'app-plan-gantt-climate-shell',
  standalone: true,
  template: '<ng-content select="[ganttActionPrefix]" />'
})
class StubPlanGanttClimateShellComponent {
  @Input({ required: true }) data!: unknown;
  @Input() planType: 'private' | 'public' = 'public';
}

@Component({
  selector: 'app-public-plan-context-header',
  standalone: true,
  template: ''
})
class StubPublicPlanContextHeaderComponent {
  @Input({ required: true }) crumbs!: unknown;
}

describe('PublicPlanResultsComponent', () => {
  let component: PublicPlanResultsComponent;
  let saveUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };
  let authService: { user: ReturnType<typeof vi.fn>; loadCurrentUser: ReturnType<typeof vi.fn> };
  let publicPlanStore: { state: { planId: number | null; farm: { name: string } } };
  let activatedRoute: { snapshot: { queryParamMap: { get: ReturnType<typeof vi.fn> } } };
  let router: { navigate: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };
  let flashMessage: { show: ReturnType<typeof vi.fn> };
  let mockTranslate: { instant: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    saveUseCase = { execute: vi.fn(() => of(undefined)) };
    loadUseCase = { execute: vi.fn(() => of(undefined)) };
    mockPresenter = { setView: vi.fn() };
    authService = { user: vi.fn(), loadCurrentUser: vi.fn(() => of(null)) };
    publicPlanStore = { state: { planId: null, farm: { name: 'Test Farm' } } };
    activatedRoute = {
      snapshot: {
        queryParamMap: { get: vi.fn() }
      }
    };
    router = { navigate: vi.fn(() => Promise.resolve(true)) };
    cdr = { markForCheck: vi.fn() };
    flashMessage = { show: vi.fn() };
    mockTranslate = {
      instant: vi.fn((key: string) => {
        if (key === 'public_plans.errors.restart') {
          return 'Please start over.';
        }
        return key;
      })
    };

    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        PublicPlanResultsComponent,
        { provide: ActivatedRoute, useValue: activatedRoute },
        { provide: Router, useValue: router },
        { provide: AuthService, useValue: authService },
        { provide: PublicPlanStore, useValue: publicPlanStore },
        { provide: FlashMessageService, useValue: flashMessage },
        { provide: LoadPublicPlanResultsUseCase, useValue: loadUseCase },
        { provide: SavePublicPlanUseCase, useValue: saveUseCase },
        { provide: PublicPlanResultsPresenter, useValue: mockPresenter },
        { provide: ChangeDetectorRef, useValue: cdr },
        { provide: TranslateService, useValue: mockTranslate }
      ]
    });

    component = TestBed.inject(PublicPlanResultsComponent);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    sessionStorage.clear();
  });

  it('implements View control getter/setter', () => {
    const state: PublicPlanResultsViewState = {
      loading: false,
      error: null,
      data: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      pendingNavigation: null
    };
    component.control = state;
    expect(component.control).toEqual(state);
    expect(cdr.markForCheck).toHaveBeenCalled();
  });

  describe('savePlan', () => {
    beforeEach(() => {
      Object.defineProperty(window, 'location', {
        value: { href: 'http://localhost:4200/public-plans/results?planId=123' },
        writable: true,
        configurable: true
      });
    });

    it('navigates to /login when user is not authenticated', () => {
      authService.user.mockReturnValue(null);
      activatedRoute.snapshot.queryParamMap.get.mockReturnValue('123');
      component.savePlan();

      expect(router.navigate).toHaveBeenCalledWith(['/login'], {
        queryParams: { return_to: 'http://localhost:4200/public-plans/results?planId=123' }
      });
      expect(sessionStorage.getItem('agrr_pending_public_plan_save')).toContain('"planId":123');
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

    it('shows flash when planId is not available', () => {
      authService.user.mockReturnValue({ id: 1, name: 'Test User' });
      activatedRoute.snapshot.queryParamMap.get.mockReturnValue(null);
      publicPlanStore.state.planId = null;

      component.savePlan();

      expect(saveUseCase.execute).not.toHaveBeenCalled();
      expect(mockTranslate.instant).toHaveBeenCalledWith('public_plans.errors.restart');
      expect(flashMessage.show).toHaveBeenCalledWith({
        type: 'error',
        text: 'Please start over.'
      });
    });
  });

  describe('pending save after login', () => {
    it('runs save once when pending exists after loadCurrentUser', () => {
      authService.user.mockReturnValue({ id: 1, name: 'Test User' });
      authService.loadCurrentUser.mockReturnValue(of({ id: 1, name: 'Test User' }));
      activatedRoute.snapshot.queryParamMap.get.mockReturnValue('123');
      sessionStorage.setItem(
        'agrr_pending_public_plan_save',
        JSON.stringify({ planId: 123, at: new Date().toISOString() })
      );

      component.ngOnInit();

      expect(saveUseCase.execute).toHaveBeenCalledTimes(1);
      expect(saveUseCase.execute).toHaveBeenCalledWith({ planId: 123 });
      expect(sessionStorage.getItem('agrr_pending_public_plan_save')).toBeNull();
    });

    it('does not run pending save twice on repeated ngOnInit', () => {
      authService.user.mockReturnValue({ id: 1, name: 'Test User' });
      authService.loadCurrentUser.mockReturnValue(of({ id: 1, name: 'Test User' }));
      activatedRoute.snapshot.queryParamMap.get.mockReturnValue('123');
      sessionStorage.setItem(
        'agrr_pending_public_plan_save',
        JSON.stringify({ planId: 123, at: new Date().toISOString() })
      );

      component.ngOnInit();
      component.ngOnInit();

      expect(saveUseCase.execute).toHaveBeenCalledTimes(1);
    });
  });

  describe('action bar layout', () => {
    let fixture: ComponentFixture<PublicPlanResultsComponent>;

    const samplePlanData = {
      data: {
        id: 1,
        planning_start_date: '2026-01-01',
        planning_end_date: '2026-12-31',
        fields: [],
        cultivations: []
      }
    };

    beforeEach(async () => {
      TestBed.resetTestingModule();

      TestBed.overrideComponent(PublicPlanResultsComponent, {
        remove: {
          imports: [PlanGanttClimateShellComponent, PublicPlanContextHeaderComponent]
        },
        add: {
          imports: [StubPlanGanttClimateShellComponent, StubPublicPlanContextHeaderComponent]
        },
        set: {
          styleUrls: [],
          providers: [
            { provide: ActivatedRoute, useValue: activatedRoute },
            { provide: Router, useValue: router },
            { provide: AuthService, useValue: authService },
            { provide: PublicPlanStore, useValue: publicPlanStore },
            { provide: FlashMessageService, useValue: flashMessage },
            { provide: LoadPublicPlanResultsUseCase, useValue: loadUseCase },
            { provide: SavePublicPlanUseCase, useValue: saveUseCase },
            { provide: PublicPlanResultsPresenter, useValue: mockPresenter },
            { provide: ChangeDetectorRef, useValue: cdr }
          ]
        }
      });

      await TestBed.configureTestingModule({
        imports: [PublicPlanResultsComponent, TranslateModule.forRoot()],
        providers: [provideRouter([])]
      }).compileComponents();

      fixture = TestBed.createComponent(PublicPlanResultsComponent);
      component = fixture.componentInstance;

      const translate = TestBed.inject(TranslateService);
      translate.setDefaultLang('ja');
      translate.use('ja');
      translate.setTranslation(
        'ja',
        {
          'public_plans.title': '無料作付け計画',
          'public_plans.save.button': 'マイプランに保存',
          'public_plans.results.view_my_plans': 'マイプランを見る',
          'public_plans.results.create_new_plan': '← 新しい計画を作成'
        },
        true
      );
    });

    it('places save CTA in gantt prefix without duplicate create-new-plan link', () => {
      authService.user.mockReturnValue(null);
      component.control = {
        loading: false,
        error: null,
        data: samplePlanData as PublicPlanResultsViewState['data'],
        pendingErrorFlash: null,
        pendingSuccessFlash: null,
        pendingNavigation: null
      };
      fixture.detectChanges();

      const root = fixture.nativeElement as HTMLElement;
      expect(root.querySelector('.public-plan-results__header-actions')).toBeNull();
      expect(root.textContent).not.toContain('← 新しい計画を作成');

      const prefix = root.querySelector('.public-plan-results__gantt-prefix');
      expect(prefix).toBeTruthy();
      const saveButton = prefix?.querySelector('button.btn.btn-primary');
      expect(saveButton?.textContent?.trim()).toBe('マイプランに保存');
    });

    it('shows view-my-plans link in gantt prefix when user is authenticated', () => {
      authService.user.mockReturnValue({ id: 1, name: 'Test User' });
      component.control = {
        loading: false,
        error: null,
        data: samplePlanData as PublicPlanResultsViewState['data'],
        pendingErrorFlash: null,
        pendingSuccessFlash: null,
        pendingNavigation: null
      };
      fixture.detectChanges();

      const prefix = fixture.nativeElement.querySelector('.public-plan-results__gantt-prefix');
      const viewLink = prefix?.querySelector('a.btn.btn-white[href="/plans"]');
      expect(viewLink?.textContent?.trim()).toBe('マイプランを見る');
    });
  });
});
