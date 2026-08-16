import { TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { ChangeDetectorRef } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { of, type Observable } from 'rxjs';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { PublicPlanResultsComponent } from './public-plan-results.component';
import { SavePublicPlanUseCase } from '../../usecase/public-plans/save-public-plan.usecase';
import { LoadPublicPlanResultsUseCase } from '../../usecase/public-plans/load-public-plan-results.usecase';
import { PublicPlanResultsPresenter } from '../../usecase/public-plans/public-plan-results.providers';
import { PublicPlanResultsViewState } from './public-plan-results.view';
import { AuthService } from '../../services/auth.service';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { FlashMessageService } from '../../services/flash-message.service';
import { AppSeoMetaService } from '../../core/seo/app-seo-meta.service';

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
  let mockTranslate: {
    instant: ReturnType<typeof vi.fn>;
    onLangChange: Observable<unknown>;
  };

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
      }),
      onLangChange: of({ lang: 'ja', translations: {} })
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
        { provide: TranslateService, useValue: mockTranslate },
        {
          provide: AppSeoMetaService,
          useValue: { refreshPublicPlanResultsMeta: vi.fn() }
        }
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
      savedPrivatePlanId: null,
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

  it('uses i18n restart key when planId is missing on init', () => {
    activatedRoute.snapshot.queryParamMap.get.mockReturnValue(null);
    publicPlanStore.state.planId = null;

    component.ngOnInit();

    expect(component.control.error).toBe('public_plans.errors.restart');
    expect(component.control.loading).toBe(false);
  });
});

describe('PublicPlanResultsComponent (template)', () => {
  it('shows a single translated error message on load failure', async () => {
    const { TestBed } = await import('@angular/core/testing');
    const { provideRouter } = await import('@angular/router');
    const { TranslateModule, TranslateService } = await import('@ngx-translate/core');
    const { PublicPlanResultsComponent } = await import('./public-plan-results.component');
    const { LoadPublicPlanResultsUseCase } = await import(
      '../../usecase/public-plans/load-public-plan-results.usecase'
    );
    const { SavePublicPlanUseCase } = await import('../../usecase/public-plans/save-public-plan.usecase');
    const { PublicPlanResultsPresenter } = await import(
      '../../usecase/public-plans/public-plan-results.providers'
    );
    const { PublicPlanStore } = await import('../../services/public-plans/public-plan-store.service');
    const { FlashMessageService } = await import('../../services/flash-message.service');
    const { AuthService } = await import('../../services/auth.service');
    const { AppSeoMetaService } = await import('../../core/seo/app-seo-meta.service');
    const { ActivatedRoute } = await import('@angular/router');
    const { of } = await import('rxjs');
    const { vi } = await import('vitest');

    await TestBed.configureTestingModule({
      imports: [PublicPlanResultsComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: LoadPublicPlanResultsUseCase, useValue: { execute: vi.fn() } },
        { provide: SavePublicPlanUseCase, useValue: { execute: vi.fn() } },
        { provide: PublicPlanResultsPresenter, useValue: { setView: vi.fn() } },
        {
          provide: PublicPlanStore,
          useValue: { state: { planId: 1, farm: { name: 'Test Farm', region: 'jp' } } }
        },
        { provide: FlashMessageService, useValue: { show: vi.fn() } },
        {
          provide: AuthService,
          useValue: { user: vi.fn(), loadCurrentUser: vi.fn(() => of(null)) }
        },
        {
          provide: AppSeoMetaService,
          useValue: { refreshPublicPlanResultsMeta: vi.fn() }
        },
        {
          provide: ActivatedRoute,
          useValue: { snapshot: { queryParamMap: { get: vi.fn().mockReturnValue('1') } } }
        }
      ]
    }).compileComponents();

    const fixture = TestBed.createComponent(PublicPlanResultsComponent);
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', {
      'public_plans.title': '計画',
      'public_plans.breadcrumb_root': '無料作付け計画',
      'public_plans.results.breadcrumb': '結果',
      'common.api_error.not_found': 'リソースが見つかりません'
    });
    translate.setDefaultLang('ja');
    translate.use('ja');

    fixture.componentInstance.control = {
      loading: false,
      error: 'common.api_error.not_found',
      data: null,
      savedPrivatePlanId: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      pendingNavigation: null
    };
    fixture.detectChanges();

    const errors = fixture.nativeElement.querySelectorAll('.error-message');
    expect(errors.length).toBe(1);
    expect(errors[0].textContent).toContain('リソースが見つかりません');
    expect(fixture.nativeElement.textContent).not.toContain('404');
    expect(fixture.nativeElement.textContent).not.toContain('Http failure');
  });

  it('shows private value preview and next steps when plan data is loaded', async () => {
    const { TestBed } = await import('@angular/core/testing');
    const { provideRouter } = await import('@angular/router');
    const { TranslateModule, TranslateService } = await import('@ngx-translate/core');
    const { PublicPlanResultsComponent } = await import('./public-plan-results.component');
    const { LoadPublicPlanResultsUseCase } = await import(
      '../../usecase/public-plans/load-public-plan-results.usecase'
    );
    const { SavePublicPlanUseCase } = await import('../../usecase/public-plans/save-public-plan.usecase');
    const { PublicPlanResultsPresenter } = await import(
      '../../usecase/public-plans/public-plan-results.providers'
    );
    const { PublicPlanStore } = await import('../../services/public-plans/public-plan-store.service');
    const { FlashMessageService } = await import('../../services/flash-message.service');
    const { AuthService } = await import('../../services/auth.service');
    const { AppSeoMetaService } = await import('../../core/seo/app-seo-meta.service');
    const { ActivatedRoute } = await import('@angular/router');
    const { of } = await import('rxjs');
    const { vi } = await import('vitest');

    await TestBed.configureTestingModule({
      imports: [PublicPlanResultsComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: LoadPublicPlanResultsUseCase, useValue: { execute: vi.fn() } },
        { provide: SavePublicPlanUseCase, useValue: { execute: vi.fn() } },
        { provide: PublicPlanResultsPresenter, useValue: { setView: vi.fn() } },
        {
          provide: PublicPlanStore,
          useValue: { state: { planId: 1, farm: { name: 'Test Farm', region: 'jp' } } }
        },
        { provide: FlashMessageService, useValue: { show: vi.fn() } },
        {
          provide: AuthService,
          useValue: { user: vi.fn(() => null), loadCurrentUser: vi.fn(() => of(null)) }
        },
        {
          provide: AppSeoMetaService,
          useValue: { refreshPublicPlanResultsMeta: vi.fn() }
        },
        {
          provide: ActivatedRoute,
          useValue: { snapshot: { queryParamMap: { get: vi.fn().mockReturnValue('1') } } }
        }
      ]
    }).compileComponents();

    const fixture = TestBed.createComponent(PublicPlanResultsComponent);
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', {
      'public_plans.title': '計画',
      'public_plans.breadcrumb_root': '無料作付け計画',
      'public_plans.results.breadcrumb': '結果',
      'public_plans.results.private_value_preview.title': 'ログイン後に使える機能',
      'public_plans.results.private_value_preview.lead': 'マイプランに保存すると利用できます。',
      'public_plans.results.private_value_preview.weather_reschedule.title': '天候リスケ',
      'public_plans.results.private_value_preview.weather_reschedule.description': '天候提案',
      'public_plans.results.private_value_preview.learn_loop.title': '学習ループ',
      'public_plans.results.private_value_preview.learn_loop.description': '学習',
      'public_plans.results.private_value_preview.work_gdd_comparison.title': '作業 GDD 比較',
      'public_plans.results.private_value_preview.work_gdd_comparison.description': 'GDD比較',
      'public_plans.results.next_steps.title': '次のステップ',
      'public_plans.results.next_steps.lead': '保存後はこの順で進めましょう。',
      'public_plans.results.next_steps.step_label.1': 'ステップ 1',
      'public_plans.results.next_steps.step_label.2': 'ステップ 2',
      'public_plans.results.next_steps.step_label.3': 'ステップ 3',
      'public_plans.results.next_steps.save.title': 'マイプランに保存',
      'public_plans.results.next_steps.save.description': '取り込み',
      'public_plans.results.next_steps.task_schedule.title': '作業予定を確認',
      'public_plans.results.next_steps.task_schedule.description': '確認',
      'public_plans.results.next_steps.work_record.title': '作業を記録',
      'public_plans.results.next_steps.work_record.description': '記録',
      'public_plans.results.next_steps.cta.login_save': 'ログインして保存',
      'public_plans.results.next_steps.after_save_hint': '保存後に利用できます',
      'public_plans.save.button': 'マイプランに保存'
    });
    translate.setDefaultLang('ja');
    translate.use('ja');

    fixture.componentInstance.control = {
      loading: false,
      error: null,
      data: {
        success: true,
        data: {
          id: 1,
          plan_year: 2026,
          plan_name: 'Test',
          status: 'active',
          total_area: 100,
          planning_start_date: '2026-01-01',
          planning_end_date: '2026-12-31',
          fields: [{ id: 1, field_id: 1, name: 'F1', area: 100, daily_fixed_cost: 0 }],
          crops: [],
          cultivations: [
            {
              id: 1,
              field_id: 1,
              field_name: 'F1',
              crop_id: 1,
              crop_name: 'C',
              area: 100,
              start_date: '2026-01-01',
              completion_date: '2026-06-01',
              cultivation_days: 150,
              estimated_cost: 0,
              revenue: 0,
              profit: 0,
              status: 'active'
            }
          ]
        },
        total_profit: 0,
        total_revenue: 0,
        total_cost: 0
      } as never,
      savedPrivatePlanId: null,
      pendingErrorFlash: null,
      pendingSuccessFlash: null,
      pendingNavigation: null
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-public-plan-private-value-preview')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('app-public-plan-results-next-steps')).not.toBeNull();
    expect(fixture.nativeElement.textContent).toContain('ログイン後に使える機能');
    expect(fixture.nativeElement.textContent).toContain('次のステップ');
    expect(fixture.nativeElement.textContent).toContain('天候リスケ');
  });
});
