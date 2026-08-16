import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanLearnInputGapSummaryComponent } from './plan-learn-input-gap-summary.component';

describe('PlanLearnInputGapSummaryComponent', () => {
  let fixture: ComponentFixture<PlanLearnInputGapSummaryComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanLearnInputGapSummaryComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation(
      'ja',
      {
        'plans.learn.input_gap.title': '入力ギャップサマリ',
        'plans.learn.input_gap.unrecorded': '未記録件数',
        'plans.learn.input_gap.action_required': '要対応件数',
        'plans.learn.input_gap.structured_unrecorded': '構造化未入力',
        'plans.learn.input_gap.amount_variance': '量乖離',
        'plans.learn.input_gap.amount_variance_work_cta': '量の乖離を確認する',
        'plans.learn.input_gap.work_cta': '未記録タスクを記録する',
        'plans.learn.input_gap.structured_work_cta': 'マスタ未選択を修正する',
        'common.loading': '読み込み中'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnInputGapSummaryComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders unrecorded and action-required counts', () => {
    fixture.componentInstance.summary = {
      unrecordedCount: 2,
      actionRequiredCount: 1,
      structuredUnrecordedCount: 0,
      amountVarianceCount: 0
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('入力ギャップサマリ');
    expect(text).toContain('未記録件数');
    expect(text).toContain('2');
    expect(text).toContain('要対応件数');
    expect(text).toContain('1');
    expect(text).toContain('構造化未入力');
    expect(text).toContain('0');
  });

  it('renders amount variance count', () => {
    fixture.componentInstance.summary = {
      unrecordedCount: 0,
      actionRequiredCount: 0,
      structuredUnrecordedCount: 0,
      amountVarianceCount: 3
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('量乖離');
    expect(text).toContain('3');
  });

  it('links to work with amount variance CTA when only amount gaps exist', () => {
    fixture.componentInstance.summary = {
      unrecordedCount: 0,
      actionRequiredCount: 0,
      structuredUnrecordedCount: 0,
      amountVarianceCount: 2
    };
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector(
      '.plan-learn-input-gap-summary__work-link'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/plans/7/work');
    expect(link.textContent?.trim()).toBe('量の乖離を確認する');
  });

  it('links to work with structured unrecorded CTA when only master selections are missing', () => {
    fixture.componentInstance.summary = {
      unrecordedCount: 0,
      actionRequiredCount: 0,
      structuredUnrecordedCount: 2,
      amountVarianceCount: 0
    };
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector(
      '.plan-learn-input-gap-summary__work-link'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/plans/7/work');
    expect(link.textContent?.trim()).toBe('マスタ未選択を修正する');
  });

  it('links to work with highlight_item when unrecorded tasks exist', () => {
    fixture.componentInstance.summary = {
      unrecordedCount: 1,
      actionRequiredCount: 0,
      structuredUnrecordedCount: 0,
      amountVarianceCount: 0
    };
    fixture.componentInstance.highlightItemId = 42;
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector(
      '.plan-learn-input-gap-summary__work-link'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/plans/7/work');
    expect(link.getAttribute('href')).toContain('highlight_item=42');
    expect(link.textContent?.trim()).toBe('未記録タスクを記録する');
  });

  it('hides work CTA when there are no unrecorded tasks or structured gaps', () => {
    fixture.componentInstance.summary = {
      unrecordedCount: 0,
      actionRequiredCount: 2,
      structuredUnrecordedCount: 0,
      amountVarianceCount: 0
    };
    fixture.detectChanges();

    expect(
      fixture.nativeElement.querySelector('.plan-learn-input-gap-summary__work-link')
    ).toBeNull();
  });
});
