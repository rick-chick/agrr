import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { WorkHubComponent } from './work-hub.component';
import { WorkHubInitUseCase } from '../../usecase/work-hub/work-hub-init.usecase';
import { LoadCrossFarmScheduleUseCase } from '../../usecase/work-hub/load-cross-farm-schedule.usecase';
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
    scheduleLoading: false,
    scheduleError: null,
    scheduleRows: [],
    scheduleFilter: { farmId: null, fieldCultivationId: null },
    pendingSuccessFlash: null,
    pendingNavigation: null,
    ...overrides
  };
}

describe('WorkHubComponent', () => {
  let fixture: ComponentFixture<WorkHubComponent>;
  let component: WorkHubComponent;
  let initExecute: ReturnType<typeof vi.fn>;
  let scheduleExecute: ReturnType<typeof vi.fn>;
  let ensureExecute: ReturnType<typeof vi.fn>;
  let mockPresenter: WorkHubPresenter & {
    setView: ReturnType<typeof vi.fn>;
  };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    initExecute = vi.fn();
    scheduleExecute = vi.fn();
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
          { provide: LoadCrossFarmScheduleUseCase, useValue: { execute: scheduleExecute } },
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
      'work.hub.no_farms': '農場がまだ登録されていません',
      'work.hub.select_farm': '農場を選択',
      'work.hub.no_fields_warning': '有効な圃場がありません',
      'work.hub.creating_plan': '計画を準備しています…',
      'work.hub.creating_plan_for': '「{{name}}」の計画を準備しています…',
      'work.hub.subtitle': '農場を選んで今日の作業を記録します',
      'work.hub.error_subtitle': '農場一覧を読み込めませんでした',
      'work.hub.retry': '再読み込み',
      'work.hub.schedule_review_title': '作業予定確認',
      'work.hub.schedule_review_lead': 'すべての農場の作業予定を月ごとにまとめて表示します。農場・圃場で絞り込めます。',
      'work.hub.filter_farm': '農場',
      'work.hub.filter_field': '圃場',
      'work.hub.filter_all_farms': '全農場',
      'work.hub.filter_all_fields': '全圃場',
      'work.hub.schedule_empty': '表示できる作業予定がありません。',
      'work.hub.schedule_row_meta': '{{farm}} · {{field}}（{{crop}}）',
      'plans.task_schedules.status.planned': '予定',
      'common.api_error.generic': 'エラーが発生しました'
    });
  });

  it('loads hub data and schedules on init', () => {
    fixture.detectChanges();
    expect(initExecute).toHaveBeenCalled();
    expect(scheduleExecute).toHaveBeenCalled();
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
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
          planId: 9
        },
        {
          farmId: 2,
          farmName: 'Farm B',
          fieldCount: 1,
          totalArea: 50,
          hasValidFields: true,
          planId: null
        }
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelectorAll('.work-hub__farm-btn')).toHaveLength(2);
  });

  it('renders unified schedule list with farm and field filters', async () => {
    fixture.detectChanges();
    component.control = baseControl({
      scheduleRows: [
        {
          item: {
            item_id: 1,
            name: '除草',
            scheduled_date: '2026-06-10',
            status: 'planned'
          } as WorkHubViewState['scheduleRows'][number]['item'],
          farmId: 1,
          farmName: 'Farm A',
          planId: 9,
          planName: 'Plan A',
          fieldName: '圃場1',
          fieldCultivationId: 101,
          cropName: 'トマト'
        },
        {
          item: {
            item_id: 2,
            name: '追肥',
            scheduled_date: '2026-06-12',
            status: 'planned'
          } as WorkHubViewState['scheduleRows'][number]['item'],
          farmId: 2,
          farmName: 'Farm B',
          planId: 10,
          planName: 'Plan B',
          fieldName: '圃場2',
          fieldCultivationId: 201,
          cropName: 'ニンジン'
        }
      ]
    });
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.textContent).toContain('作業予定確認');
    expect(fixture.nativeElement.querySelectorAll('.work-hub__schedule-item')).toHaveLength(2);
    expect(fixture.nativeElement.querySelectorAll('.work-hub__filter-select')).toHaveLength(2);

    component.onFarmFilterChange(1);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelectorAll('.work-hub__schedule-item')).toHaveLength(1);
    expect(fixture.nativeElement.textContent).toContain('除草');
    expect(fixture.nativeElement.textContent).not.toContain('追肥');
  });

  it('groups schedule cards by month with day-only dates inside cards', async () => {
    fixture.detectChanges();
    component.control = baseControl({
      scheduleRows: [
        {
          item: {
            item_id: 1,
            name: '除草',
            scheduled_date: '2026-06-10',
            status: 'planned'
          } as WorkHubViewState['scheduleRows'][number]['item'],
          farmId: 1,
          farmName: 'Farm A',
          planId: 9,
          planName: 'Plan A',
          fieldName: '圃場1',
          fieldCultivationId: 101,
          cropName: 'トマト'
        },
        {
          item: {
            item_id: 2,
            name: '追肥',
            scheduled_date: '2026-06-12',
            status: 'planned'
          } as WorkHubViewState['scheduleRows'][number]['item'],
          farmId: 2,
          farmName: 'Farm B',
          planId: 10,
          planName: 'Plan B',
          fieldName: '圃場2',
          fieldCultivationId: 201,
          cropName: 'ニンジン'
        },
        {
          item: {
            item_id: 3,
            name: '収穫',
            scheduled_date: '2026-07-01',
            status: 'planned'
          } as WorkHubViewState['scheduleRows'][number]['item'],
          farmId: 1,
          farmName: 'Farm A',
          planId: 9,
          planName: 'Plan A',
          fieldName: '圃場1',
          fieldCultivationId: 101,
          cropName: 'トマト'
        }
      ]
    });
    fixture.detectChanges();
    await fixture.whenStable();

    const monthSections = fixture.nativeElement.querySelectorAll('.work-hub__schedule-month');
    expect(monthSections).toHaveLength(2);

    const monthTitles = fixture.nativeElement.querySelectorAll('.work-hub__schedule-month-title');
    expect(monthTitles[0].textContent?.trim()).toBe('2026年6月');
    expect(monthTitles[1].textContent?.trim()).toBe('2026年7月');

    const dayLabels = [...fixture.nativeElement.querySelectorAll('.work-hub__schedule-date')].map(
      (el: Element) => el.textContent?.trim()
    );
    expect(dayLabels).toEqual(['10日', '12日', '1日']);
  });

  it('ensures plan when a farm is selected', () => {
    fixture.detectChanges();
    component.selectFarm({
      farmId: 3,
      farmName: 'Farm C',
      fieldCount: 1,
      totalArea: 40,
      hasValidFields: true,
      planId: null
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
          planId: 9
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
          planId: null
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
          planId: null
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
          planId: null
        }
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('エラーが発生しました');
    expect(fixture.nativeElement.querySelectorAll('.work-hub__farm-btn')).toHaveLength(1);
    expect(fixture.nativeElement.textContent).toContain('再読み込み');
  });

  it('reloads hub data when retry is clicked', () => {
    fixture.detectChanges();
    component.control = baseControl({ error: 'common.api_error.generic' });
    fixture.detectChanges();

    initExecute.mockClear();
    const retryButtons = fixture.nativeElement.querySelectorAll('.work-hub__retry');
    retryButtons[retryButtons.length - 1]?.click();

    expect(initExecute).toHaveBeenCalled();
  });
});
