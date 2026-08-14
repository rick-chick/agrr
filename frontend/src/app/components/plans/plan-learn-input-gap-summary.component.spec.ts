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
        'plans.learn.input_gap.work_cta': '未記録タスクを記録する',
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
      actionRequiredCount: 1
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('入力ギャップサマリ');
    expect(text).toContain('未記録件数');
    expect(text).toContain('2');
    expect(text).toContain('要対応件数');
    expect(text).toContain('1');
  });

  it('links to work with highlight_item when unrecorded tasks exist', () => {
    fixture.componentInstance.summary = {
      unrecordedCount: 1,
      actionRequiredCount: 0
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

  it('hides work CTA when there are no unrecorded tasks', () => {
    fixture.componentInstance.summary = {
      unrecordedCount: 0,
      actionRequiredCount: 2
    };
    fixture.detectChanges();

    expect(
      fixture.nativeElement.querySelector('.plan-learn-input-gap-summary__work-link')
    ).toBeNull();
  });
});
