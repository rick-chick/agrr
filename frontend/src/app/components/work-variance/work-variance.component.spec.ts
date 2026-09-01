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
      'work.variance.filters.clear': '条件をクリア',
      'work.variance.filters.active_chip': '{{label}}: {{value}}',
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
      'work.variance.status.pending': '保留',
      'common.loading': '読み込み中'
    });
  });

  function withControl(overrides: Partial<WorkVarianceViewState> = {}): void {
    const reloadSpy = vi.spyOn(component, 'reload').mockImplementation(() => {});
    try {
      component.control = baseControl(overrides);
      fixture.detectChanges();
    } finally {
      reloadSpy.mockRestore();
    }
  }

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
            carryoverNotImported: false,
            weatherTriggerCount: 0
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
                carryoverNotImported: false,
            weatherTriggerCount: 0
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
      rows: [{ farmId: 1, farmName: 'Farm A', planId: 10, planYear: 2026, status: 'completed', unrecordedCount: 0, gddDelayCount: 0, thresholdExceededCount: 0, daysThresholdExceededCount: 0, carryoverNotImported: false, weatherTriggerCount: 0 }],
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

  function portfolioFixtureData() {
    return {
      rows: [
        {
          farmId: 1,
          farmName: 'Farm A',
          planId: 10,
          planYear: 2026,
          status: 'completed',
          unrecordedCount: 0,
          gddDelayCount: 0,
          thresholdExceededCount: 0,
          daysThresholdExceededCount: 0,
          carryoverNotImported: false,
          weatherTriggerCount: 0
        }
      ],
      filterOptions: {
        farms: [{ farmId: 1, farmName: 'Farm A' }],
        statuses: ['completed', 'pending'],
        planYears: [2026]
      },
      portfolioSummary: {
        unrecordedCount: 0,
        actionRequiredCount: 0,
        gddDelayCount: 0,
        daysThresholdExceededCount: 0
      }
    };
  }

  it('renders filter toolbar before portfolio summary in DOM order', () => {
    withControl(portfolioFixtureData());

    const html = fixture.nativeElement as HTMLElement;
    const filters = html.querySelector('.work-variance__filters');
    const summary = html.querySelector('.work-variance__portfolio-summary');
    expect(filters).toBeTruthy();
    expect(summary).toBeTruthy();
    expect(
      filters!.compareDocumentPosition(summary!) & Node.DOCUMENT_POSITION_FOLLOWING
    ).toBeTruthy();
  });

  it('renders status filter as chip buttons instead of select', () => {
    withControl(portfolioFixtureData());

    const html = fixture.nativeElement as HTMLElement;
    const statusGroup = html.querySelector('.work-variance__status-chips');
    expect(statusGroup).toBeTruthy();
    expect(html.querySelector('.work-variance__status-select')).toBeNull();
    expect(statusGroup!.querySelectorAll('.work-variance__status-chip').length).toBeGreaterThan(1);
  });

  it('applies status filter when a chip is selected', () => {
    withControl(portfolioFixtureData());

    component.onStatusChipSelect('pending');

    expect(applyFilters).toHaveBeenCalledWith({
      farmId: null,
      status: 'pending',
      planYear: null
    });
  });

  it('shows active filter chips and clear control when filters are applied', () => {
    withControl({
      ...portfolioFixtureData(),
      filters: { farmId: 1, status: 'completed', planYear: 2026 }
    });

    const html = fixture.nativeElement as HTMLElement;
    expect(html.querySelector('.work-variance__active-filters')).toBeTruthy();
    expect(html.textContent).toContain('条件をクリア');
    expect(html.querySelectorAll('.work-variance__active-filter-chip').length).toBe(3);
  });

  it('clears all filters via clear control', () => {
    withControl({
      ...portfolioFixtureData(),
      filters: { farmId: 1, status: 'completed', planYear: 2026 }
    });

    component.clearFilters();

    expect(applyFilters).toHaveBeenCalledWith({
      farmId: null,
      status: null,
      planYear: null
    });
  });

  it('exposes aria-live polite on portfolio summary', () => {
    withControl(portfolioFixtureData());

    const summary = (fixture.nativeElement as HTMLElement).querySelector(
      '.work-variance__portfolio-summary'
    );
    expect(summary?.getAttribute('aria-live')).toBe('polite');
  });
});
