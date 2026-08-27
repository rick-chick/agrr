import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { WorkHubComponent } from './work-hub.component';
import { WorkHubInitUseCase } from '../../usecase/work-hub/work-hub-init.usecase';
import { EnsurePlanForFarmUseCase } from '../../usecase/work-hub/ensure-plan-for-farm.usecase';
import { WorkHubPresenter } from '../../adapters/work-hub/work-hub.presenter';
import type { WorkHubViewState } from './work-hub.view';

function baseControl(
  overrides: Partial<WorkHubViewState> = {}
): WorkHubViewState {
  return {
    loading: false,
    submitting: false,
    error: null,
    farms: [],
    portfolioSummary: null,
    varianceCoverage: null,
    attentionList: null,
    pendingSuccessFlash: null,
    pendingNavigation: null,
    ...overrides
  };
}

describe('WorkHubComponent', () => {
  let fixture: ComponentFixture<WorkHubComponent>;
  let component: WorkHubComponent;
  let initExecute: ReturnType<typeof vi.fn>;
  let ensureExecute: ReturnType<typeof vi.fn>;
  let mockPresenter: WorkHubPresenter & {
    setView: ReturnType<typeof vi.fn>;
  };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    initExecute = vi.fn();
    ensureExecute = vi.fn();
    mockPresenter = {
      setView: vi.fn(),
      present: vi.fn(),
      onError: vi.fn(),
      onSuccess: vi.fn()
    } as unknown as WorkHubPresenter & {
      setView: ReturnType<typeof vi.fn>;
    };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(WorkHubComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: WorkHubInitUseCase, useValue: { execute: initExecute } },
          { provide: EnsurePlanForFarmUseCase, useValue: { execute: ensureExecute } },
          { provide: WorkHubPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [WorkHubComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(WorkHubComponent);
    component = fixture.componentInstance;

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation('ja', {
      'work.hub.title': '作業ハブ',
      'work.hub.no_farms': '農場がまだ登録されていません',
      'work.hub.select_farm': '農場を選択',
      'work.hub.no_fields_warning': '有効な圃場がありません',
      'work.hub.creating_plan': '計画を準備しています…',
      'work.hub.creating_plan_for': '「{{name}}」の計画を準備しています…',
      'work.hub.subtitle': '農場を選んで今日の作業を記録します',
      'work.hub.error_subtitle': '農場一覧を読み込めませんでした',
      'work.hub.retry': '再読み込み',
      'work.hub.farm_meta': '圃場 {{count}} 件・合計 {{area}} ㎡',
      'work.hub.overdue_summary': '期限超過 {{count}} 件',
      'work.hub.today_summary': '今日 {{count}} 件',
      'work.hub.unrecorded_summary': '未記録 {{count}} 件',
      'work.hub.gdd_delay_summary': 'GDD遅延 {{count}} 件',
      'work.hub.threshold_exceeded_summary': '要対応 {{count}} 件',
      'work.hub.context_attention_badge': '注意',
      'work.hub.context_attention_badge_aria': '計画芯で要対応 {{count}} 件',
      'work.hub.portfolio_summary.title': '全農場サマリ',
      'work.hub.portfolio_summary.unrecorded': '未記録',
      'work.hub.portfolio_summary.action_required': '要対応',
      'work.hub.portfolio_summary.gdd_delay': 'GDD遅延',
      'work.hub.portfolio_summary.threshold_exceeded': '閾値超過',
      'work.hub.portfolio_summary.variance_coverage': '{{farms}} 農場 / {{plans}} 計画に乖離',
      'work.hub.portfolio_summary.view_variance_portfolio': '乖離横断を見る',
      'work.hub.other_plans_badge': '他 {{count}} 計画あり',
      'work.hub.other_plans_badge_aria': '代表計画以外に乖離のある計画が {{count}} 件あります',
      'work.hub.attention_list.title': '要対応タスク（上位）',
      'work.hub.attention_list.item': '{{farm}} · {{task}}',
      'work.hub.attention_list.weather_trigger_item': '{{farm}} · 天候トリガー {{count}} 件',
      'work.hub.attention_list.open_work': '作業へ',
      'work.hub.attention_list.open_learn': '振り返りへ',
      'plans.work.today_attention.weather_trigger.frost_forecast': '霜予報',
      'plans.work.today_attention.weather_trigger.gdd_trajectory_delay': 'GDD軌道遅延',
      'plans.work.today_attention.weather_trigger.forecast_sudden_change': '予報急変',
      'common.api_error.generic': 'エラーが発生しました'
    });
  });

  it('loads hub data on init', () => {
    fixture.detectChanges();
    expect(initExecute).toHaveBeenCalled();
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
  });

  it('wraps content in AppShell with work hub title', () => {
    fixture.detectChanges();
    component.control = baseControl();
    fixture.detectChanges();

    const shell = fixture.nativeElement.querySelector('app-app-shell');
    expect(shell).toBeTruthy();
    expect(fixture.nativeElement.querySelector('h1#page-title')?.textContent?.trim()).toBe('作業ハブ');
    expect(fixture.nativeElement.querySelector('.page-main')).toBeTruthy();
  });

  it('does not render schedule review section', () => {
    fixture.detectChanges();
    component.control = baseControl({
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9,
          overdueCount: 2,
          todayCount: 1,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0,
          unrecordedCount: 0
        }
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.work-hub__schedule')).toBeNull();
    expect(fixture.nativeElement.textContent).not.toContain('作業予定確認');
    expect(fixture.nativeElement.querySelectorAll('.work-hub__filter-select')).toHaveLength(0);
  });

  it('shows empty state when no farms are returned', () => {
    fixture.detectChanges();
    component.control = baseControl();
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('農場がまだ登録されていません');
  });

  it('shows farm picker when multiple farms exist', () => {
    fixture.detectChanges();
    component.control = baseControl({
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9,
          overdueCount: 2,
          todayCount: 1,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0,
          unrecordedCount: 0
        },
        {
          farmId: 2,
          farmName: 'Farm B',
          fieldCount: 1,
          totalArea: 50,
          hasValidFields: true,
          planId: null,
          overdueCount: 0,
          todayCount: 0,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0,
          unrecordedCount: 0
        }
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelectorAll('.work-hub__farm-btn')).toHaveLength(2);
  });

  it('ensures plan when a farm is selected', () => {
    fixture.detectChanges();
    component.selectFarm({
      farmId: 3,
      farmName: 'Farm C',
      fieldCount: 1,
      totalArea: 40,
      hasValidFields: true,
      planId: null,
      overdueCount: 0,
      todayCount: 0,
      unrecordedCount: 0,
      gddDelayCount: 0,
      daysExceedanceCount: 0,
      thresholdExceededCount: 0,
      otherVariancePlanCount: 0
    });
    expect(component.control.submitting).toBe(true);
    expect(ensureExecute).toHaveBeenCalledWith({ farmId: 3, existingPlanId: null });
  });

  it('shows farm picker when a single farm exists', () => {
    fixture.detectChanges();
    component.control = baseControl({
      farms: [
        {
          farmId: 1,
          farmName: 'Farm Solo',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9,
          overdueCount: 2,
          todayCount: 1,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0,
          unrecordedCount: 0
        }
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelectorAll('.work-hub__farm-btn')).toHaveLength(1);
  });

  it('shows field warning for a single farm without valid fields', () => {
    fixture.detectChanges();
    component.control = baseControl({
      farms: [
        {
          farmId: 1,
          farmName: 'Farm Solo',
          fieldCount: 0,
          totalArea: 0,
          hasValidFields: false,
          planId: null,
          overdueCount: 0,
          todayCount: 0,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0,
          unrecordedCount: 0
        }
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('有効な圃場がありません');
    expect(fixture.nativeElement.querySelector('.work-hub__farm-btn')?.disabled).toBe(true);
  });

  it('shows creating plan message while submitting and keeps farm list visible', () => {
    fixture.detectChanges();
    component.control = baseControl({
      submitting: true,
      farms: [
        {
          farmId: 1,
          farmName: 'Farm Solo',
          fieldCount: 1,
          totalArea: 50,
          hasValidFields: true,
          planId: null,
          overdueCount: 0,
          todayCount: 0,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0,
          unrecordedCount: 0
        }
      ]
    });
    component.selectedFarmName = 'Farm Solo';
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('「Farm Solo」の計画を準備しています…');
    expect(fixture.nativeElement.querySelectorAll('.work-hub__farm-btn')).toHaveLength(1);
    expect(fixture.nativeElement.querySelector('.page-description')?.textContent).toContain(
      '農場を選んで今日の作業を記録します'
    );
  });

  it('shows error subtitle instead of default subtitle when load fails', () => {
    fixture.detectChanges();
    component.control = baseControl({ error: 'common.api_error.generic' });
    fixture.detectChanges();

    const description = fixture.nativeElement.querySelector('.page-description');
    expect(description?.textContent).toContain('農場一覧を読み込めませんでした');
    expect(description?.textContent).not.toContain('農場を選んで今日の作業を記録します');
  });

  it('shows error with retry and keeps farm list visible', () => {
    fixture.detectChanges();
    component.control = baseControl({
      error: 'common.api_error.generic',
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: null,
          overdueCount: 0,
          todayCount: 0,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0,
          unrecordedCount: 0
        }
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('エラーが発生しました');
    expect(fixture.nativeElement.querySelectorAll('.work-hub__farm-btn')).toHaveLength(1);
    expect(fixture.nativeElement.textContent).toContain('再読み込み');
  });

  it('shows overdue and today counts on farm cards', () => {
    fixture.detectChanges();
    component.control = baseControl({
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9,
          overdueCount: 2,
          todayCount: 1,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0,
          unrecordedCount: 0
        },
        {
          farmId: 2,
          farmName: 'Farm B',
          fieldCount: 1,
          totalArea: 50,
          hasValidFields: true,
          planId: 10,
          overdueCount: 0,
          todayCount: 0,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0,
          unrecordedCount: 0
        }
      ]
    });
    fixture.detectChanges();

    const summary = fixture.nativeElement.querySelector('.work-hub__summary');
    expect(summary?.textContent).toContain('期限超過 2 件');
    expect(summary?.textContent).toContain('今日 1 件');
    expect(fixture.nativeElement.textContent).toContain('期限超過 0 件');
    expect(fixture.nativeElement.textContent).toContain('今日 0 件');
  });

  it('shows gdd delay and threshold exceeded counts on farm cards', () => {
    fixture.detectChanges();
    component.control = baseControl({
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9,
          overdueCount: 0,
          todayCount: 0,
          unrecordedCount: 0,
          gddDelayCount: 2,
          daysExceedanceCount: 1,
          thresholdExceededCount: 3,
          otherVariancePlanCount: 0
        }
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('GDD遅延 2 件');
    expect(fixture.nativeElement.textContent).toContain('要対応 3 件');
  });

  it('shows unrecorded count on farm cards', () => {
    fixture.detectChanges();
    component.control = baseControl({
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9,
          overdueCount: 0,
          todayCount: 0,
          unrecordedCount: 5,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0
        }
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('未記録 5 件');
  });

  it('shows context attention badge when threshold exceeded count is positive', () => {
    fixture.detectChanges();
    component.control = baseControl({
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9,
          overdueCount: 0,
          todayCount: 0,
          unrecordedCount: 0,
          gddDelayCount: 1,
          daysExceedanceCount: 0,
          thresholdExceededCount: 2,
          otherVariancePlanCount: 0
        },
        {
          farmId: 2,
          farmName: 'Farm B',
          fieldCount: 1,
          totalArea: 50,
          hasValidFields: true,
          planId: 10,
          overdueCount: 0,
          todayCount: 0,
          unrecordedCount: 0,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0
        }
      ]
    });
    fixture.detectChanges();

    const badges = fixture.nativeElement.querySelectorAll('.work-hub__context-badge');
    expect(badges).toHaveLength(1);
    expect(badges[0]?.textContent).toContain('注意');
    expect(badges[0]?.getAttribute('aria-label')).toContain('計画芯で要対応 2 件');
  });

  it('shows portfolio summary band with aggregated counts across farms', () => {
    fixture.detectChanges();
    component.control = baseControl({
      portfolioSummary: {
        unrecordedCount: 5,
        actionRequiredCount: 7,
        gddDelayCount: 3,
        daysThresholdExceededCount: 4
      },
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9,
          overdueCount: 2,
          todayCount: 1,
          unrecordedCount: 3,
          gddDelayCount: 2,
          daysExceedanceCount: 2,
          thresholdExceededCount: 4,
          otherVariancePlanCount: 0
        },
        {
          farmId: 2,
          farmName: 'Farm B',
          fieldCount: 1,
          totalArea: 50,
          hasValidFields: true,
          planId: 10,
          overdueCount: 0,
          todayCount: 0,
          unrecordedCount: 2,
          gddDelayCount: 1,
          daysExceedanceCount: 2,
          thresholdExceededCount: 3,
          otherVariancePlanCount: 0
        }
      ]
    });
    fixture.detectChanges();

    const band = fixture.nativeElement.querySelector('.work-hub__portfolio-summary');
    expect(band).not.toBeNull();
    expect(band?.textContent).toContain('全農場サマリ');
    expect(band?.textContent).toContain('未記録');
    expect(band?.textContent).toContain('5');
    expect(band?.textContent).toContain('要対応');
    expect(band?.textContent).toContain('7');
    expect(band?.textContent).toContain('GDD遅延');
    expect(band?.textContent).toContain('3');
    expect(band?.textContent).toContain('閾値超過');
    expect(band?.textContent).toContain('4');
  });

  it('shows portfolio summary band for single-farm auto-redirect while submitting', () => {
    fixture.detectChanges();
    component.control = baseControl({
      submitting: true,
      portfolioSummary: {
        unrecordedCount: 2,
        actionRequiredCount: 1,
        gddDelayCount: 1,
        daysThresholdExceededCount: 1
      },
      farms: [
        {
          farmId: 1,
          farmName: 'Farm Solo',
          fieldCount: 1,
          totalArea: 50,
          hasValidFields: true,
          planId: 9,
          overdueCount: 0,
          todayCount: 0,
          unrecordedCount: 2,
          gddDelayCount: 1,
          daysExceedanceCount: 1,
          thresholdExceededCount: 1,
          otherVariancePlanCount: 0
        }
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.work-hub__portfolio-summary')).not.toBeNull();
    expect(fixture.nativeElement.textContent).toContain('2');
    expect(fixture.nativeElement.textContent).toContain('全農場サマリ');
  });

  it('shows cross-farm attention list with links to work or learn', () => {
    fixture.detectChanges();
    component.control = baseControl({
      portfolioSummary: {
        unrecordedCount: 0,
        actionRequiredCount: 2,
        gddDelayCount: 1,
        daysThresholdExceededCount: 1
      },
      attentionList: {
        items: [
          {
            kind: 'variance',
            farmId: 1,
            farmName: 'Farm A',
            planId: 9,
            itemId: 1,
            taskName: '追肥',
            linkTarget: 'learn'
          },
          {
            kind: 'variance',
            farmId: 2,
            farmName: 'Farm B',
            planId: 10,
            itemId: 2,
            taskName: '除草',
            linkTarget: 'work'
          }
        ]
      },
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9,
          overdueCount: 0,
          todayCount: 0,
          unrecordedCount: 0,
          gddDelayCount: 1,
          daysExceedanceCount: 1,
          thresholdExceededCount: 1,
          otherVariancePlanCount: 0
        },
        {
          farmId: 2,
          farmName: 'Farm B',
          fieldCount: 1,
          totalArea: 50,
          hasValidFields: true,
          planId: 10,
          overdueCount: 0,
          todayCount: 0,
          unrecordedCount: 0,
          gddDelayCount: 0,
          daysExceedanceCount: 1,
          thresholdExceededCount: 1,
          otherVariancePlanCount: 0
        }
      ]
    });
    fixture.detectChanges();

    const list = fixture.nativeElement.querySelector('.work-hub__attention-list');
    expect(list).not.toBeNull();
    expect(list?.textContent).toContain('要対応タスク（上位）');
    expect(list?.textContent).toContain('Farm A · 追肥');
    expect(list?.textContent).toContain('Farm B · 除草');

    const links = fixture.nativeElement.querySelectorAll('.work-hub__attention-list-link');
    expect(links).toHaveLength(2);
    expect(links[0]?.getAttribute('href')).toContain('/plans/9/learn');
    expect(links[1]?.getAttribute('href')).toContain('/plans/10/work');
  });

  it('shows weather trigger attention row with type badges linking to plan work', () => {
    fixture.detectChanges();
    component.control = baseControl({
      portfolioSummary: {
        unrecordedCount: 0,
        actionRequiredCount: 0,
        gddDelayCount: 0,
        daysThresholdExceededCount: 0
      },
      attentionList: {
        items: [
          {
            kind: 'weather_trigger',
            farmId: 1,
            farmName: 'Farm A',
            planId: 9,
            itemId: -9,
            weatherTriggerCount: 2,
            weatherTriggerTypes: ['frost_forecast', 'gdd_trajectory_delay'],
            linkTarget: 'work'
          }
        ]
      },
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 1,
          totalArea: 50,
          hasValidFields: true,
          planId: 9,
          overdueCount: 0,
          todayCount: 0,
          unrecordedCount: 0,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 0,
          otherVariancePlanCount: 0
        }
      ]
    });
    fixture.detectChanges();

    const list = fixture.nativeElement.querySelector('.work-hub__attention-list');
    expect(list?.textContent).toContain('Farm A · 天候トリガー 2 件');
    expect(list?.textContent).toContain('霜予報');
    expect(list?.textContent).toContain('GDD軌道遅延');

    const link = fixture.nativeElement.querySelector('.work-hub__attention-list-link') as HTMLAnchorElement;
    expect(link?.getAttribute('href')).toContain('/plans/9/work');
    expect(fixture.nativeElement.querySelectorAll('.work-hub__attention-list-badge')).toHaveLength(2);
  });

  it('reloads hub data when retry is clicked', () => {
    fixture.detectChanges();
    component.control = baseControl({ error: 'common.api_error.generic' });
    fixture.detectChanges();

    initExecute.mockClear();
    const retryButton = fixture.nativeElement.querySelector('.work-hub__retry');
    retryButton?.click();

    expect(initExecute).toHaveBeenCalled();
  });

  it('shows variance portfolio link and coverage text in portfolio summary', () => {
    fixture.detectChanges();
    component.control = baseControl({
      portfolioSummary: {
        unrecordedCount: 1,
        actionRequiredCount: 2,
        gddDelayCount: 1,
        daysThresholdExceededCount: 1
      },
      varianceCoverage: { farmCount: 2, planCount: 3 },
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9,
          overdueCount: 0,
          todayCount: 0,
          unrecordedCount: 1,
          gddDelayCount: 1,
          daysExceedanceCount: 1,
          thresholdExceededCount: 2,
          otherVariancePlanCount: 0
        }
      ]
    });
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('.work-hub__variance-link') as HTMLAnchorElement;
    expect(link?.textContent).toContain('乖離横断を見る');
    expect(link?.getAttribute('href')).toContain('/work/variance');
    expect(fixture.nativeElement.textContent).toContain('2 農場 / 3 計画に乖離');
  });

  it('shows other plans badge when otherVariancePlanCount is positive', () => {
    fixture.detectChanges();
    component.control = baseControl({
      portfolioSummary: {
        unrecordedCount: 0,
        actionRequiredCount: 1,
        gddDelayCount: 0,
        daysThresholdExceededCount: 0
      },
      varianceCoverage: { farmCount: 1, planCount: 2 },
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9,
          overdueCount: 0,
          todayCount: 0,
          unrecordedCount: 0,
          gddDelayCount: 0,
          daysExceedanceCount: 0,
          thresholdExceededCount: 1,
          otherVariancePlanCount: 2
        }
      ]
    });
    fixture.detectChanges();

    const badge = fixture.nativeElement.querySelector('.work-hub__other-plans-badge');
    expect(badge?.textContent).toContain('他 2 計画あり');
    expect(badge?.getAttribute('aria-label')).toContain('代表計画以外に乖離のある計画が 2 件あります');
  });
});
