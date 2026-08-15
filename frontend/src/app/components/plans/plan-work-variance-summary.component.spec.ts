import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanWorkVarianceSummaryComponent } from './plan-work-variance-summary.component';

describe('PlanWorkVarianceSummaryComponent', () => {
  let fixture: ComponentFixture<PlanWorkVarianceSummaryComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanWorkVarianceSummaryComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(PlanWorkVarianceSummaryComponent);
    fixture.componentInstance.planId = 7;
    translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation(
      'ja',
      {
        'plans.work.variance_summary.title': '入力ギャップサマリ',
        'plans.work.variance_summary.unrecorded': '未記録',
        'plans.work.variance_summary.threshold_exceeded': '要対応',
        'plans.work.variance_summary.gdd_delay': 'GDD遅延',
        'plans.work.variance_summary.learn_cta': '振り返りで詳細を見る',
        'common.loading': '読み込み中'
      },
      true
    );
  });

  it('renders summary counts and learn CTA when stats are loaded', () => {
    fixture.componentInstance.stats = {
      unrecordedCount: 2,
      thresholdExceededCount: 3,
      gddDelayCount: 1,
      daysExceedanceCount: 0
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('未記録');
    expect(text).toContain('2');
    expect(text).toContain('要対応');
    expect(text).toContain('3');
    expect(text).toContain('GDD遅延');
    expect(text).toContain('1');

    const learnLink = fixture.nativeElement.querySelector(
      '.plan-work-variance-summary__learn-link'
    ) as HTMLAnchorElement;
    expect(learnLink).toBeTruthy();
    expect(learnLink.getAttribute('href')).toContain('/plans/7/learn');
    expect(learnLink.textContent?.trim()).toBe('振り返りで詳細を見る');
  });

  it('shows loading state while variance summary is loading', () => {
    fixture.componentInstance.loading = true;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.master-loading')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.plan-work-variance-summary__grid')).toBeNull();
  });
});
