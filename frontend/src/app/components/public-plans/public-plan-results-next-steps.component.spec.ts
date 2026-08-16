import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import {
  buildPublicPlanResultsNextSteps,
  PublicPlanResultsNextStepsComponent
} from './public-plan-results-next-steps.component';

const nextStepsTranslations = {
  'public_plans.results.next_steps.title': '次のステップ',
  'public_plans.results.next_steps.lead': '保存後はこの順で進めましょう。',
  'public_plans.results.next_steps.step_label.1': 'ステップ 1',
  'public_plans.results.next_steps.step_label.2': 'ステップ 2',
  'public_plans.results.next_steps.step_label.3': 'ステップ 3',
  'public_plans.results.next_steps.save.title': 'マイプランに保存',
  'public_plans.results.next_steps.save.description': 'この計画を自分のアカウントに取り込みます',
  'public_plans.results.next_steps.task_schedule.title': '作業予定を確認',
  'public_plans.results.next_steps.task_schedule.description':
    '作業スケジュールと GDD のタイミングを確認',
  'public_plans.results.next_steps.work_record.title': '作業を記録',
  'public_plans.results.next_steps.work_record.description':
    '圃場での作業実績を記録し計画と比較',
  'public_plans.results.next_steps.cta.login_save': 'ログインして保存',
  'public_plans.results.next_steps.cta.save': '上のボタンで保存',
  'public_plans.results.next_steps.cta.task_schedule': '作業予定を見る',
  'public_plans.results.next_steps.cta.work_record': '作業記録へ',
  'public_plans.results.next_steps.completed': '完了',
  'public_plans.results.next_steps.after_save_hint': '保存後に利用できます'
};

describe('buildPublicPlanResultsNextSteps', () => {
  it('builds three steps without links before save', () => {
    const steps = buildPublicPlanResultsNextSteps(null);
    expect(steps).toHaveLength(3);
    expect(steps[0].stepKey).toBe('save');
    expect(steps[1].commands).toBeUndefined();
    expect(steps[2].commands).toBeUndefined();
  });

  it('builds navigation commands after save', () => {
    const steps = buildPublicPlanResultsNextSteps(42);
    expect(steps[1].commands).toEqual(['/plans', 42, 'task_schedule']);
    expect(steps[2].commands).toEqual(['/plans', 42, 'work_records']);
  });
});

describe('PublicPlanResultsNextStepsComponent', () => {
  let fixture: ComponentFixture<PublicPlanResultsNextStepsComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PublicPlanResultsNextStepsComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation('ja', nextStepsTranslations, true);

    fixture = TestBed.createComponent(PublicPlanResultsNextStepsComponent);
  });

  it('shows login hint on step 1 when guest', () => {
    fixture.componentInstance.isLoggedIn = false;
    fixture.componentInstance.savedPrivatePlanId = null;
    fixture.detectChanges();

    const hints = fixture.nativeElement.querySelectorAll('.public-plan-results-next-steps__hint');
    expect(hints.length).toBeGreaterThan(0);
    expect(fixture.nativeElement.textContent).toContain('ログインして保存');
    expect(fixture.nativeElement.textContent).toContain('保存後に利用できます');
  });

  it('shows save hint on step 1 when logged in before save', () => {
    fixture.componentInstance.isLoggedIn = true;
    fixture.componentInstance.savedPrivatePlanId = null;
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('上のボタンで保存');
    expect(fixture.nativeElement.querySelectorAll('a.public-plan-results-next-steps__cta')).toHaveLength(
      0
    );
  });

  it('marks step 1 completed and links steps 2-3 after save', () => {
    fixture.componentInstance.isLoggedIn = true;
    fixture.componentInstance.savedPrivatePlanId = 42;
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('完了');
    const links = fixture.nativeElement.querySelectorAll('a.public-plan-results-next-steps__cta');
    expect(links).toHaveLength(2);
    expect(links[0].getAttribute('href')).toBe('/plans/42/task_schedule');
    expect(links[1].getAttribute('href')).toBe('/plans/42/work_records');
  });
});
