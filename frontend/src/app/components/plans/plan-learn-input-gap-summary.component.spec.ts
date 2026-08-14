import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanLearnInputGapSummaryComponent } from './plan-learn-input-gap-summary.component';

describe('PlanLearnInputGapSummaryComponent', () => {
  let fixture: ComponentFixture<PlanLearnInputGapSummaryComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanLearnInputGapSummaryComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(PlanLearnInputGapSummaryComponent);
    fixture.componentInstance.planId = 7;
    translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation(
      'ja',
      {
        'plans.learn.input_gap.title': '入力ギャップサマリ',
        'plans.learn.input_gap.unrecorded': '未記録',
        'plans.learn.input_gap.action_required': '閾値超過',
        'plans.learn.input_gap.work_cta': '作業を記録する',
        'common.loading': '読み込み中'
      },
      true
    );
  });

  it('renders summary counts when stats are loaded', () => {
    fixture.componentInstance.stats = { unrecordedCount: 2, actionRequiredCount: 3 };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('入力ギャップサマリ');
    expect(text).toContain('未記録');
    expect(text).toContain('2');
    expect(text).toContain('閾値超過');
    expect(text).toContain('3');
  });

  it('links to work page with task_schedule_item_id when unrecorded and focusItemId provided', () => {
    fixture.componentInstance.stats = { unrecordedCount: 1, actionRequiredCount: 0 };
    fixture.componentInstance.focusItemId = 42;
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector(
      '.plan-learn-input-gap-summary__work-link'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/plans/7/work');
    expect(link.getAttribute('href')).toContain('task_schedule_item_id=42');
    expect(link.textContent?.trim()).toBe('作業を記録する');
  });

  it('links to work page without query param when unrecorded but no focusItemId', () => {
    fixture.componentInstance.stats = { unrecordedCount: 1, actionRequiredCount: 0 };
    fixture.componentInstance.focusItemId = null;
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector(
      '.plan-learn-input-gap-summary__work-link'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toBe('/plans/7/work');
  });

  it('does not render work CTA when unrecorded count is zero', () => {
    fixture.componentInstance.stats = { unrecordedCount: 0, actionRequiredCount: 2 };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-learn-input-gap-summary__work-link')).toBeNull();
  });

  it('shows loading state while variance summary is loading', () => {
    fixture.componentInstance.loading = true;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.master-loading')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.plan-learn-input-gap-summary__grid')).toBeNull();
  });
});
