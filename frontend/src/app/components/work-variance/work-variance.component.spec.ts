import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { WorkVarianceComponent } from './work-variance.component';
import { WorkVarianceInitUseCase } from '../../usecase/work-variance/work-variance-init.usecase';
import { WorkVariancePresenter } from '../../adapters/work-variance/work-variance.presenter';
import type { WorkVarianceViewState } from './work-variance.view';

function baseControl(overrides: Partial<WorkVarianceViewState> = {}): WorkVarianceViewState {
  return {
    loading: false,
    error: null,
    rows: [],
    filters: { farmId: null, status: null, planYear: null },
    filterOptions: { farms: [], statuses: [], planYears: [] },
    farmGroups: [],
    portfolioSummary: null,
    attentionList: null,
    ...overrides
  };
}

describe('WorkVarianceComponent', () => {
  let fixture: ComponentFixture<WorkVarianceComponent>;
  let component: WorkVarianceComponent;
  let initExecute: ReturnType<typeof vi.fn>;
  let applyFilters: ReturnType<typeof vi.fn>;
  let mockPresenter: WorkVariancePresenter & { setView: ReturnType<typeof vi.fn> };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    initExecute = vi.fn();
    applyFilters = vi.fn();
    mockPresenter = {
      setView: vi.fn(),
      present: vi.fn(),
      onError: vi.fn()
    } as unknown as WorkVariancePresenter & { setView: ReturnType<typeof vi.fn> };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(WorkVarianceComponent, {
      set: {
        styleUrls: [],
        providers: [
          {
            provide: WorkVarianceInitUseCase,
            useValue: { execute: initExecute, applyFilters }
          },
          { provide: WorkVariancePresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [WorkVarianceComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(WorkVarianceComponent);
    component = fixture.componentInstance;

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation('ja', {
      'work.variance.title': '乖離ポートフォリオ',
      'work.variance.subtitle': '農場×計画×年度の乖離を横断比較します',
      'work.variance.error_subtitle': '読み込みに失敗しました',
      'work.variance.portfolio_summary.title': 'サマリ',
      'work.variance.portfolio_summary.unrecorded': '未記録',
      'work.variance.portfolio_summary.action_required': '要対応',
      'work.variance.portfolio_summary.gdd_delay': 'GDD遅延',
      'work.variance.portfolio_summary.threshold_exceeded': '閾値超過',
      'work.variance.filters.title': 'フィルタ',
      'work.variance.filters.farm': '農場',
      'work.variance.filters.status': 'ステータス',
      'work.variance.filters.year': '年度',
      'work.variance.filters.all': 'すべて',
      'work.variance.attention_list.title': '要対応タスク',
      'work.variance.attention_list.item': '{{farm}} · {{task}}',
      'work.variance.no_plans': '計画がありません',
      'work.variance.no_plans_hint': '計画を作成してください',
      'work.variance.create_plan_link': '計画を作成',
      'work.variance.no_filter_results': '条件に一致する行がありません',
      'work.variance.table.year': '年度',
      'work.variance.table.status': 'ステータス',
      'work.variance.table.unrecorded': '未記録',
      'work.variance.table.gdd_delay': 'GDD遅延',
      'work.variance.table.threshold_exceeded': '要対応',
      'work.variance.table.actions': '操作',
      'work.variance.table.work_link': '作業',
      'work.variance.table.learn_link': '学習',
      'work.variance.table.plan_link': '計画',
      'work.variance.status.completed': '完了',
      'common.loading': '読み込み中'
    });
  });

  it('loads portfolio data on init', () => {
    fixture.detectChanges();
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(initExecute).toHaveBeenCalled();
  });

  it('renders farm groups with navigation links only', async () => {
    const reloadSpy = vi.spyOn(component, 'reload').mockImplementation(() => {});
    try {
      component.control = baseControl({
        rows: [
          {
            farmId: 1,
            farmName: 'Farm A',
            planId: 10,
            planYear: 2026,
            status: 'completed',
            unrecordedCount: 1,
            gddDelayCount: 0,
            thresholdExceededCount: 2,
            daysThresholdExceededCount: 2,
            carryoverNotImported: false
          }
        ],
        farmGroups: [
          {
            farmId: 1,
            farmName: 'Farm A',
            plans: [
              {
                farmId: 1,
                farmName: 'Farm A',
                planId: 10,
                planYear: 2026,
                status: 'completed',
                unrecordedCount: 1,
                gddDelayCount: 0,
                thresholdExceededCount: 2,
                daysThresholdExceededCount: 2,
                carryoverNotImported: false
              }
            ]
          }
        ],
        portfolioSummary: {
          unrecordedCount: 1,
          actionRequiredCount: 2,
          gddDelayCount: 0,
          daysThresholdExceededCount: 2
        }
      });
      fixture.detectChanges();
      await fixture.whenStable();

      const html = fixture.nativeElement as HTMLElement;
      expect(html.textContent).toContain('Farm A');
      expect(html.textContent).toContain('完了');
      expect(html.querySelector('a[href="/plans/10/work"]')).toBeTruthy();
      expect(html.querySelector('a[href="/plans/10/learn"]')).toBeTruthy();
      expect(html.querySelector('a[href="/plans/10"]')).toBeTruthy();
    } finally {
      reloadSpy.mockRestore();
    }
  });

  it('applies farm filter via use case', () => {
    component.control = baseControl({
      rows: [{ farmId: 1, farmName: 'Farm A', planId: 10, planYear: 2026, status: 'completed', unrecordedCount: 0, gddDelayCount: 0, thresholdExceededCount: 0, daysThresholdExceededCount: 0, carryoverNotImported: false }],
      filterOptions: { farms: [{ farmId: 1, farmName: 'Farm A' }], statuses: ['completed'], planYears: [2026] },
      portfolioSummary: {
        unrecordedCount: 0,
        actionRequiredCount: 0,
        gddDelayCount: 0,
        daysThresholdExceededCount: 0
      }
    });
    fixture.detectChanges();

    component.onFarmFilterChange({ target: { value: '1' } } as unknown as Event);

    expect(applyFilters).toHaveBeenCalledWith({
      farmId: 1,
      status: null,
      planYear: null
    });
  });
});
