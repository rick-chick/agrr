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
        'public_plans.title': '無料作付け計画',
        'public_plans.breadcrumb_root': '新規',
        'public_plans.optimizing.breadcrumb': '最適化中',
        'public_plans.optimizing.status_badge_failed': '作成失敗',
        'public_plans.optimizing.crops_count': '{{count}}種類の作物',
        'public_plans.optimizing.error.title': '計画作成に失敗しました',
        'public_plans.optimizing.error.try_again': '作物を変更してもう一度試す',
        'public_plans.optimizing.error.start_over': '最初からやり直す',
        'public_plans.optimizing.error.hints.predicting_weather':
          '気象データの準備に時間がかかっている可能性があります。しばらく待ってから再度お試しください。',
        'public_plans.optimizing.error.hints.default':
          '下のボタンから作物を変更するか、最初からやり直してください。'
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
