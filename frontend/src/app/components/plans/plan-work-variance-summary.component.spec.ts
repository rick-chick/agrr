import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { PlanWorkVarianceSummaryComponent } from './plan-work-variance-summary.component';

describe('PlanWorkVarianceSummaryComponent', () => {
  let fixture: ComponentFixture<PlanWorkVarianceSummaryComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanWorkVarianceSummaryComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation(
      'ja',
      {
        'common.loading': '読み込み中',
        'plans.work.variance.summary_line':
          '未記録 {{unrecorded}} 件 · 閾値超過 {{threshold}} 件 · GDD遅延 {{gddDelay}} 件',
        'plans.work.variance.learn_cta': '振り返りで確認'
      },
      true
    );

    fixture = TestBed.createComponent(PlanWorkVarianceSummaryComponent);
    fixture.componentInstance.planId = 7;
  });

  afterEach(() => {
    fixture.destroy();
  });

  it('renders summary counts and learn CTA link', () => {
    fixture.componentInstance.stats = {
      unrecordedCount: 2,
      thresholdExceedanceCount: 3,
      gddDelayCount: 1
    };
    fixture.detectChanges();

    const line = fixture.nativeElement.querySelector('.plan-work-variance-summary__line');
    expect(line?.textContent).toContain('未記録 2 件');
    expect(line?.textContent).toContain('閾値超過 3 件');
    expect(line?.textContent).toContain('GDD遅延 1 件');

    const link = fixture.nativeElement.querySelector('.plan-work-variance-summary__cta');
    expect(link?.textContent?.trim()).toBe('振り返りで確認');
    expect(link?.getAttribute('href')).toContain('/plans/7/learn');
  });

  it('shows loading state', () => {
    fixture.componentInstance.loading = true;
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('読み込み中');
    expect(fixture.nativeElement.querySelector('.plan-work-variance-summary__cta')).toBeNull();
  });
});
