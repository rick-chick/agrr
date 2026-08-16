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
        'plans.work.today_attention.gdd_delay': 'GDD遅延',
        'plans.work.today_attention.threshold_exceeded': '閾値超過',
        'plans.work.today_attention.frost_risk_field': '{{field}}（{{crop}}）',
        'plans.work.today_attention.gdd_delay_task': 'GDD遅延: {{name}}',
        'plans.work.today_attention.threshold_exceeded_task': '閾値超過: {{name}}',
        'plans.work.today_attention.learn_cta': '振り返りで詳細を見る',
        'plans.work.today_attention.weather_trigger.frost_forecast': '霜予報',
        'plans.work.today_attention.weather_trigger.gdd_trajectory_delay': 'GDD軌道遅延',
        'plans.work.today_attention.weather_trigger.forecast_sudden_change': '予報急変',
        'plans.work.today_attention.weather_target': '{{field}}（{{crop}}）',
        'plans.work.today_attention.weather_rationale.frost_forecast':
          '最低気温 {{tMin}}℃（閾値 {{threshold}}℃）',
        'plans.work.today_attention.weather_proposal_cta': '提案を見る',
        'common.loading': '読み込み中'
      },
      true
    );
  });

  it('renders attention summary counts, details, and learn CTA', () => {
    fixture.componentInstance.summary = {
      frostRiskCount: 1,
      frostRiskFields: [
        { fieldCultivationId: 10, fieldName: '北圃場', cropName: 'トマト' }
      ],
      gddDelayCount: 1,
      gddDelayTasks: [{ itemId: 2, name: '間引き' }],
      thresholdExceededCount: 2,
      thresholdExceededTasks: [
        { itemId: 1, name: '追肥' },
        { itemId: 2, name: '間引き' }
      ],
      weatherTriggers: [],
      hasAnyAttention: true
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('今日の注意');
    expect(text).toContain('霜リスク');
    expect(text).toContain('北圃場');
    expect(text).toContain('GDD遅延: 間引き');
    expect(text).toContain('閾値超過: 追肥');

    const learnLink = fixture.nativeElement.querySelector(
      '.plan-work-today-attention__learn-link'
    ) as HTMLAnchorElement;
    expect(learnLink?.getAttribute('href')).toContain('/plans/7/learn');
  });

  it('renders weather trigger type, rationale, target field/crop, and proposal CTA', () => {
    fixture.componentInstance.summary = {
      frostRiskCount: 0,
      frostRiskFields: [],
      gddDelayCount: 0,
      gddDelayTasks: [],
      thresholdExceededCount: 0,
      thresholdExceededTasks: [],
      weatherTriggers: [
        {
          proposalId: 'frost_forecast:100:42',
          triggerType: 'frost_forecast',
          fieldName: '北圃場',
          cropName: 'トマト',
          rationaleI18nKey: 'plans.work.today_attention.weather_rationale.frost_forecast',
          rationaleI18nParams: { tMin: -2, threshold: 0 }
        }
      ],
      hasAnyAttention: true
    };
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('霜予報');
    expect(text).toContain('北圃場（トマト）');
    expect(text).toContain('最低気温 -2℃（閾値 0℃）');
    expect(text).toContain('提案を見る');

    const proposalLink = fixture.nativeElement.querySelector(
      '.plan-work-today-attention__proposal-link'
    ) as HTMLAnchorElement;
    expect(proposalLink?.getAttribute('href')).toContain('/plans/7');
    expect(proposalLink?.getAttribute('href')).toContain('weatherProposal=frost_forecast');
  });

  it('hides the card when there is no attention summary', () => {
    fixture.componentInstance.summary = {
      frostRiskCount: 0,
      frostRiskFields: [],
      gddDelayCount: 0,
      gddDelayTasks: [],
      thresholdExceededCount: 0,
      thresholdExceededTasks: [],
      weatherTriggers: [],
      hasAnyAttention: false
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-work-today-attention')).toBeNull();
  });

  it('shows loading state while attention summary is loading', () => {
    fixture.componentInstance.loading = true;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.master-loading')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.plan-work-today-attention__grid')).toBeNull();
  });
});
