import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, TranslationObject } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';
import { PlanWorkComponent } from './plan-work.component';
import { PlanWorkViewState } from './plan-work.view';
import { LoadWorkDayListUseCase } from '../../usecase/plans/load-work-day-list.usecase';
import { SkipTaskScheduleItemUseCase } from '../../usecase/plans/skip-task-schedule-item.usecase';
import { PlanWorkPresenter } from '../../adapters/plans/plan-work.presenter';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import { TaskScheduleItem } from '../../models/plans/task-schedule';

function mockRow(overrides: Partial<TaskScheduleItem> = {}): WorkDayListRowDto {
  return {
    item: {
      item_id: 1,
      name: '追肥',
      task_type: 'field_work',
      category: 'general',
      scheduled_date: '2026-06-17',
      stage_name: '',
      stage_order: 0,
      gdd_trigger: '',
      gdd_tolerance: '',
      priority: 1,
      source: 'agrr',
      weather_dependency: 'none',
      time_per_sqm: '',
      amount: '',
      amount_unit: '',
      status: 'pending',
      agricultural_task_id: 1,
      field_cultivation_id: 1,
      completed: false,
      work_records: [],
      details: {},
      badge: { label: '', tone: 'default' },
      ...overrides
    } as TaskScheduleItem,
    fieldName: 'A区画',
    cropName: 'トマト',
    recordedToday: false
  };
}

const loadedState: PlanWorkViewState = {
  loading: false,
  error: null,
  plan: {
    id: 7,
    name: 'テスト計画',
    status: 'completed',
    planning_start_date: '2026-01-01',
    planning_end_date: '2026-12-31',
    timeline_generated_at: '2026-06-01T00:00:00Z',
    timeline_generated_at_display: '2026-06-01'
  },
  fields: [],
  overdue: [mockRow({ item_id: 10, name: '遅延作業' })],
  today: [mockRow({ item_id: 11, name: '今日の作業' })],
  upcoming: [],
  includeSkipped: false
};

describe('PlanWorkComponent mobile UX', () => {
  let fixture: ComponentFixture<PlanWorkComponent>;
  let component: PlanWorkComponent;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let skipUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: {
    setView: ReturnType<typeof vi.fn>;
    onSkipSuccessCallback: (() => void) | null;
  };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    skipUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn(), onSkipSuccessCallback: null };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(PlanWorkComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadWorkDayListUseCase, useValue: loadUseCase },
          { provide: SkipTaskScheduleItemUseCase, useValue: skipUseCase },
          { provide: PlanWorkPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanWorkComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: { paramMap: { get: vi.fn(() => '7') } }
          }
        }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(PlanWorkComponent);
    component = fixture.componentInstance;

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation(
      'ja',
      {
        'plans.work.back_to_plan': '計画に戻る',
        'plans.work.title': '作業 — {{name}}',
        'plans.work.show_skipped': 'スキップを表示',
        'plans.work.section.overdue': '期限超過 ({{count}})',
        'plans.work.section.today': '今日 {{date}}',
        'plans.work.section.upcoming': '今後7日',
        'plans.work.complete': '完了',
        'plans.work.add_record': '+ 実績を登録',
        'plans.work.empty_today': '今日の作業はありません',
        'plans.work.recorded_today': '本日記録済み',
        'plans.work.skipped_badge': 'スキップ済み',
        'plans.work.menu': 'メニュー',
        'plans.work.skip': 'スキップ',
        'plans.work.unskip': 'スキップ解除',
        'plans.work.nav.work': '作業',
        'plans.work.nav.schedule': '予定表',
        'plans.work.nav.history': '実績履歴'
      },
      true
    );
  });

  afterEach(() => {
    fixture.destroy();
  });

  function renderLoaded(): void {
    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
  }

  it('uses a large primary complete button with 44px min touch target', () => {
    renderLoaded();
    const completeBtn = fixture.nativeElement.querySelector('.plan-work__complete-btn');
    expect(completeBtn).toBeTruthy();
    expect(completeBtn.classList.contains('btn-sm')).toBe(false);
    expect(completeBtn.classList.contains('btn-primary')).toBe(true);
  });

  it('uses a subdued icon-only menu button separate from complete', () => {
    renderLoaded();
    const menuBtn = fixture.nativeElement.querySelector('.plan-work__menu-btn');
    expect(menuBtn).toBeTruthy();
    expect(menuBtn.textContent?.trim()).toBe('⋮');
    expect(menuBtn.classList.contains('btn-sm')).toBe(false);
  });

  it('marks overdue rows with overdue modifier class', () => {
    renderLoaded();
    const overdueRow = fixture.nativeElement.querySelector('.plan-work__row--overdue');
    expect(overdueRow).toBeTruthy();
    expect(overdueRow.textContent).toContain('遅延作業');
  });

  it('distinguishes done and skip badges with separate classes', () => {
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      today: [
        { ...mockRow({ item_id: 20 }), recordedToday: true },
        mockRow({ item_id: 21, status: 'skipped' })
      ],
      overdue: []
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-work__done-badge')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.plan-work__skip-badge')).toBeTruthy();
  });

  it('renders add-record FAB with fixed positioning hook class', () => {
    renderLoaded();
    const fab = fixture.nativeElement.querySelector('.plan-work__fab');
    expect(fab).toBeTruthy();
    expect(fab.classList.contains('plan-work__fab--fixed')).toBe(true);
  });

  it('reloads with includeSkipped when show-skipped toggle is checked', () => {
    renderLoaded();
    loadUseCase.execute.mockClear();

    const checkbox = fixture.nativeElement.querySelector(
      '.plan-work__toggle input[type="checkbox"]'
    ) as HTMLInputElement;
    expect(checkbox).toBeTruthy();
    checkbox.checked = true;
    checkbox.dispatchEvent(new Event('change'));

    expect(loadUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 7, includeSkipped: true })
    );
  });
});

describe('PlanWorkComponent in locale labels', () => {
  let fixture: ComponentFixture<PlanWorkComponent>;
  let component: PlanWorkComponent;
  let translate: TranslateService;

  beforeEach(async () => {
    const loadUseCase = { execute: vi.fn() };
    const skipUseCase = { execute: vi.fn() };
    const mockPresenter = { setView: vi.fn(), onSkipSuccessCallback: null };
    const cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(PlanWorkComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadWorkDayListUseCase, useValue: loadUseCase },
          { provide: SkipTaskScheduleItemUseCase, useValue: skipUseCase },
          { provide: PlanWorkPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanWorkComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: { paramMap: { get: vi.fn(() => '7') } }
          }
        }
      ]
    }).compileComponents();

    translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', ja as TranslationObject, true);
    translate.setTranslation('in', inLocale as TranslationObject, true);
    translate.setDefaultLang('ja');
    translate.use('in');

    fixture = TestBed.createComponent(PlanWorkComponent);
    component = fixture.componentInstance;
  });

  afterEach(() => {
    fixture.destroy();
  });

  it('renders Hindi nav tabs and empty state instead of ja fallback', async () => {
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      overdue: [],
      today: [],
      upcoming: []
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const navLinks = fixture.nativeElement.querySelectorAll('.plan-work-nav__link');
    expect(navLinks.length).toBe(3);
    expect(navLinks[0].textContent?.trim()).toBe('आज का कार्य');
    expect(navLinks[1].textContent?.trim()).toBe('पूर्ण अनुसूची');
    expect(navLinks[2].textContent?.trim()).toBe('कार्य इतिहास');

    const empty = fixture.nativeElement.querySelector('.plan-work__empty');
    expect(empty?.textContent?.trim()).toBe('आज के लिए कोई कार्य निर्धारित नहीं');
    expect(empty?.textContent?.trim()).not.toBe('今日の予定はありません');
  });
});
