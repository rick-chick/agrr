import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { PublicPlanOptimizingComponent } from './public-plan-optimizing.component';
import { PublicPlanOptimizingViewState } from './public-plan-optimizing.view';
import { SubscribePublicPlanOptimizationUseCase } from '../../usecase/public-plans/subscribe-public-plan-optimization.usecase';
import { PublicPlanOptimizingPresenter } from '../../usecase/public-plans/public-plan-optimizing.providers';
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';

describe('PublicPlanOptimizingComponent', () => {
  let fixture: ComponentFixture<PublicPlanOptimizingComponent>;
  let component: PublicPlanOptimizingComponent;
  let mockUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: { setView: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };

    TestBed.overrideComponent(PublicPlanOptimizingComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: SubscribePublicPlanOptimizationUseCase, useValue: mockUseCase },
          { provide: PublicPlanOptimizingPresenter, useValue: mockPresenter },
          {
            provide: ActivatedRoute,
            useValue: {
              snapshot: { queryParamMap: { get: vi.fn().mockReturnValue('1') } }
            }
          },
          {
            provide: PublicPlanStore,
            useValue: {
              state: {
                farm: { id: 1, name: 'Test Farm', region: 'jp' },
                selectedCrops: [{ id: 1 }],
                planId: 1
              }
            }
          },
          { provide: ChangeDetectorRef, useValue: { markForCheck: vi.fn(), detectChanges: vi.fn() } }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PublicPlanOptimizingComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(PublicPlanOptimizingComponent);
    component = fixture.componentInstance;

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation(
      'ja',
      {
        'public_plans.title': '作付け計画を作成',
        'public_plans.breadcrumb_root': '作付け計画を作成',
        'public_plans.optimizing.breadcrumb': '最適化中',
        'public_plans.optimizing.status_badge_failed': '作成失敗',
        'public_plans.optimizing.crops_count': '{{count}}種類の作物',
        'public_plans.optimizing.error.title': '計画作成に失敗しました',
        'public_plans.optimizing.error.reload': '再読み込み',
        'public_plans.optimizing.error.try_again': '作物を変更してもう一度試す',
        'public_plans.optimizing.error.start_over': '最初からやり直す',
        'public_plans.optimizing.error.hints.predicting_weather':
          '気象データの準備に時間がかかっている可能性があります。しばらく待ってから再度お試しください。',
        'public_plans.optimizing.error.hints.default':
          '下のボタンから作物を変更するか、最初からやり直してください。',
        'models.cultivation_plan.phase_failed.timeout': '処理がタイムアウトしました',
        'public_plans.optimizing.error.hints.timeout':
          '処理に時間がかかりすぎました。しばらく待ってから再度お試しください。'
      },
      true
    );
  });

  it('shows failure category detail and hint when optimization fails', () => {
    const state: PublicPlanOptimizingViewState = {
      status: 'failed',
      progress: 0,
      phaseMessage: '気象データの予測に失敗しました',
      failureHint:
        '気象データの準備に時間がかかっている可能性があります。しばらく待ってから再度お試しください。'
    };
    component.control = state;
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('計画作成に失敗しました');
    expect(text).toContain('気象データの予測に失敗しました');
    expect(text).toContain(
      '気象データの準備に時間がかかっている可能性があります。しばらく待ってから再度お試しください。'
    );
    expect(text).not.toContain('処理に失敗しました');
  });

  it('keeps retry actions when optimization fails', () => {
    component.control = {
      status: 'failed',
      progress: 0,
      phaseMessage: '最適化に失敗しました',
      failureHint: '下のボタンから作物を変更するか、最初からやり直してください。'
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('作物を変更してもう一度試す');
    expect(text).toContain('最初からやり直す');
  });

  it('renders accessible error panel in main content when optimization fails', () => {
    component.control = {
      status: 'failed',
      progress: 0,
      phaseMessage: '気象データの取得に失敗しました',
      failureHint: '地域や農場の設定を確認し、しばらく時間をおいてから再度お試しください。'
    };
    fixture.detectChanges();

    const alert = fixture.nativeElement.querySelector(
      '.page-alert-error.public-plan-optimizing__error[role="alert"]'
    );
    expect(alert).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.fixed-progress-bar')).toBeFalsy();
  });

  it('uses secondary buttons and a tertiary link for recovery actions', () => {
    component.control = {
      status: 'failed',
      progress: 0,
      phaseMessage: '気象データの取得に失敗しました',
      failureHint: '地域や農場の設定を確認し、しばらく時間をおいてから再度お試しください。'
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelectorAll('.btn-primary').length).toBe(0);

    const actions = fixture.nativeElement.querySelector('.public-plan-optimizing__error-actions');
    const actionButtons = actions?.querySelectorAll('.btn');
    expect(actionButtons?.length).toBe(2);
    expect(actionButtons?.[0].classList.contains('btn-secondary')).toBe(true);
    expect(actionButtons?.[1].classList.contains('btn-secondary')).toBe(true);

    const startOverLink = fixture.nativeElement.querySelector(
      '.public-plan-optimizing__error-secondary a'
    ) as HTMLAnchorElement;
    expect(startOverLink?.textContent).toContain('最初からやり直す');
  });

  it('shows timeout category detail and hint when optimization times out', () => {
    component.control = {
      status: 'failed',
      progress: 0,
      phaseMessage: '処理がタイムアウトしました',
      failureHint: '処理に時間がかかりすぎました。しばらく待ってから再度お試しください。'
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('計画作成に失敗しました');
    expect(text).toContain('処理がタイムアウトしました');
    expect(text).toContain('処理に時間がかかりすぎました。しばらく待ってから再度お試しください。');
    expect(text).not.toContain('worker timeout');
  });

  it('shows fallback hint when failure detail is generic', () => {
    component.control = {
      status: 'failed',
      progress: 0,
      phaseMessage: '処理に失敗しました',
      failureHint: '下のボタンから作物を変更するか、最初からやり直してください。'
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('処理に失敗しました');
    expect(text).toContain('下のボタンから作物を変更するか、最初からやり直してください。');
  });
});
