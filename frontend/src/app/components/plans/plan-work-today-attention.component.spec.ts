import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanWorkTodayAttentionComponent } from './plan-work-today-attention.component';

describe('PlanWorkTodayAttentionComponent', () => {
  let fixture: ComponentFixture<PlanWorkTodayAttentionComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanWorkTodayAttentionComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(PlanWorkTodayAttentionComponent);
    fixture.componentInstance.planId = 7;
    translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation(
      'ja',
      {
        'plans.work.today_attention.title': '今日の注意',
        'plans.work.today_attention.frost_risk': '霜リスク',
        'plans.work.today_attention.threshold_exceeded': '閾値超過',
        'plans.work.today_attention.gdd_delay': 'GDD遅延',
        'plans.work.today_attention.learn_cta': '振り返りで詳細を見る',
        'plans.work.today_attention.empty': '本日の注意事項はありません',
        'common.loading': '読み込み中'
      },
      true
    );
  });

  it('renders frost risk, threshold exceeded, gdd delay counts and learn link', () => {
    fixture.componentInstance.attention = {
      frostRiskCount: 2,
      thresholdExceededCount: 3,
      gddDelayCount: 1
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('今日の注意');
    expect(text).toContain('霜リスク');
    expect(text).toContain('2');
    expect(text).toContain('閾値超過');
    expect(text).toContain('3');
    expect(text).toContain('GDD遅延');
    expect(text).toContain('1');

    const learnLink = fixture.nativeElement.querySelector(
      '.plan-work-today-attention__learn-link'
    ) as HTMLAnchorElement;
    expect(learnLink).toBeTruthy();
    expect(learnLink.getAttribute('href')).toContain('/plans/7/learn');
    expect(learnLink.textContent?.trim()).toBe('振り返りで詳細を見る');
  });

  it('hides the card when there are no alerts and empty state is disabled', () => {
    fixture.componentInstance.attention = null;
    fixture.componentInstance.showEmptyState = false;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-work-today-attention')).toBeNull();
  });

  it('shows empty state message when enabled and there are no alerts', () => {
    fixture.componentInstance.attention = null;
    fixture.componentInstance.showEmptyState = true;
    fixture.detectChanges();

    const section = fixture.nativeElement.querySelector('.plan-work-today-attention--empty');
    expect(section).toBeTruthy();
    expect(section.textContent).toContain('本日の注意事項はありません');
  });

  it('shows loading state while frost risk data is loading', () => {
    fixture.componentInstance.loading = true;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.master-loading')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.plan-work-today-attention__grid')).toBeNull();
  });
});
