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
import { CreateWorkRecordUseCase } from '../../usecase/plans/create-work-record.usecase';
import { PlanWorkPresenter } from '../../adapters/plans/plan-work.presenter';
import { RegenerateTaskScheduleUseCase } from '../../usecase/plans/regenerate-task-schedule.usecase';
import { SubscribeTaskScheduleSyncUseCase } from '../../usecase/plans/subscribe-task-schedule-sync.usecase';
import { WorkRecordSheetSavedEvent } from './work-record-sheet.view';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import { UndoToastService } from '../../services/undo-toast.service';
import { TaskScheduleItem } from '../../models/plans/task-schedule';

const initialControl: PlanWorkViewState = {
  loading: true,
  error: null,
  plan: null,
  fields: [],
  overdue: [],
  today: [],
  upcoming: [],
  includeSkipped: false,
  recentAdHocRecord: null,
  highlightedItemId: null,
  completingItemId: null,
  regenerating: false,
  regenerateError: null,
  pendingSyncToastKey: null,
  pendingRecordSavedToastKey: null,
  syncReloadNonce: 0
};

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
    timeline_generated_at_display: '2026-06-01',
    task_schedule_sync_state: 'ready',
    task_schedule_sync_error: null
  },
  fields: [],
  overdue: [mockRow({ item_id: 10, name: '遅延作業' })],
  today: [mockRow({ item_id: 11, name: '今日の作業' })],
  upcoming: [],
  includeSkipped: false,
  recentAdHocRecord: null,
  highlightedItemId: null,
  completingItemId: null,
  regenerating: false,
  regenerateError: null,
  pendingSyncToastKey: null,
  pendingRecordSavedToastKey: null,
  syncReloadNonce: 0
};

describe('PlanWorkComponent mobile UX', () => {
  let fixture: ComponentFixture<PlanWorkComponent>;
  let component: PlanWorkComponent;
  let translate: TranslateService;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let skipUseCase: { execute: ReturnType<typeof vi.fn> };
  let createUseCase: { execute: ReturnType<typeof vi.fn> };
  let regenerateUseCase: { execute: ReturnType<typeof vi.fn> };
  let subscribeSyncUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: {
    setView: ReturnType<typeof vi.fn>;
    onSkipSuccessCallback: (() => void) | null;
    onRecordSavedCallback: ((event: WorkRecordSheetSavedEvent) => void) | null;
  };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    skipUseCase = { execute: vi.fn() };
    createUseCase = { execute: vi.fn() };
    regenerateUseCase = { execute: vi.fn() };
    subscribeSyncUseCase = { execute: vi.fn() };
    mockPresenter = {
      setView: vi.fn(),
      onSkipSuccessCallback: null,
      onRecordSavedCallback: null
    };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(PlanWorkComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadWorkDayListUseCase, useValue: loadUseCase },
          { provide: SkipTaskScheduleItemUseCase, useValue: skipUseCase },
          { provide: CreateWorkRecordUseCase, useValue: createUseCase },
          { provide: RegenerateTaskScheduleUseCase, useValue: regenerateUseCase },
          { provide: SubscribeTaskScheduleSyncUseCase, useValue: subscribeSyncUseCase },
          { provide: PlanWorkPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanWorkComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: UndoToastService, useValue: { show: vi.fn() } },
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

    translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation(
      'ja',
      {
        'plans.work.back_to_plan': '計画に戻る',
        'plans.work.back_to_hub': '作業記録トップへ',
        'plans.work.title': '作業 — {{name}}',
        'plans.work.show_skipped': 'スキップを表示',
        'plans.work.section.overdue': '期限超過 ({{count}})',
        'plans.work.section.today': '今日 {{date}}',
        'plans.work.section.upcoming': '今後7日',
      'plans.work.complete': '完了',
      'plans.work.record_with_details': '詳細を記録',
      'plans.work.add_record': '+ 実績を登録',
        'plans.work.empty_today': '今日の作業はありません',
        'plans.work.empty_today_hint': '予定外の作業は下のボタンから記録できます',
        'plans.work.recent_adhoc': '「{{name}}」（{{date}}）を記録しました',
        'plans.work.recent_adhoc_history_link': '実績履歴で見る',
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

  it('shows a single primary back link to the work hub in the page header', () => {
    renderLoaded();
    expect(fixture.nativeElement.querySelector('.plan-work__back-nav')).toBeNull();
    const back = fixture.nativeElement.querySelector('.plan-work-header__back');
    expect(back?.textContent).toContain('作業記録トップへ');
  });

  it('shows plan detail as a secondary link in the page description', () => {
    renderLoaded();
    const planLink = fixture.nativeElement.querySelector('.plan-work-header__plan-link');
    expect(planLink?.textContent).toContain('計画に戻る');
  });

  it('uses page-header and section-card shell consistent with work hub', () => {
    renderLoaded();
    const header = fixture.nativeElement.querySelector('.page-header');
    const card = fixture.nativeElement.querySelector('.section-card');
    expect(header).toBeTruthy();
    expect(card).toBeTruthy();
    expect(card.contains(header)).toBe(false);
    expect(header.querySelector('.page-title')).toBeTruthy();
  });

  it('uses a large primary complete button with 44px min touch target', () => {
    renderLoaded();
    const completeBtn = fixture.nativeElement.querySelector('.plan-work__complete-btn');
    expect(completeBtn).toBeTruthy();
    expect(completeBtn.classList.contains('btn-sm')).toBe(false);
    expect(completeBtn.classList.contains('btn-primary')).toBe(true);
  });

  it('records scheduled task on complete click without opening the sheet', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-06-25T12:00:00'));
    renderLoaded();
    const sheet = component.sheet;
    const openFromItemSpy = vi.spyOn(sheet, 'openFromItem');

    const completeBtn = fixture.nativeElement.querySelector(
      '.plan-work__complete-btn'
    ) as HTMLButtonElement;
    completeBtn.click();

    expect(createUseCase.execute).toHaveBeenCalledWith({
      planId: 7,
      body: { task_schedule_item_id: 10, actual_date: '2026-06-25' }
    });
    expect(openFromItemSpy).not.toHaveBeenCalled();
    vi.useRealTimers();
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

  it('renders add-record button in footer when today has tasks', () => {
    renderLoaded();
    const fab = fixture.nativeElement.querySelector('.plan-work__fab');
    expect(fab).toBeTruthy();
    const fabBtn = fab.querySelector('.plan-work__fab-btn');
    expect(fabBtn?.classList.contains('btn-primary')).toBe(true);
    expect(fabBtn?.classList.contains('plan-work__cta--constrained')).toBe(true);
    expect(fixture.nativeElement.querySelector('.plan-work__empty-cta')).toBeNull();
  });

  it('embeds add-record in empty state and hides footer when today has no tasks', () => {
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      overdue: [],
      today: [],
      upcoming: []
    };
    fixture.detectChanges();

    const empty = fixture.nativeElement.querySelector('.plan-work__empty');
    expect(empty).toBeTruthy();
    expect(empty.querySelector('.plan-work__empty-message')?.textContent).toContain('今日の作業はありません');
    expect(empty.querySelector('.plan-work__empty-hint')).toBeTruthy();
    expect(empty.querySelector('.plan-work__empty-cta')?.classList.contains('btn-primary')).toBe(true);
    expect(empty.querySelector('.plan-work__empty-cta')?.classList.contains('plan-work__cta--constrained')).toBe(
      true
    );
    expect(fixture.nativeElement.querySelector('.plan-work__fab')).toBeNull();
  });

  it('places show-skipped toggle in the today section header row', () => {
    renderLoaded();
    const header = fixture.nativeElement.querySelector('.plan-work__section-header');
    expect(header?.querySelector('.plan-work__section-title')).toBeTruthy();
    const toggle = header?.querySelector('.plan-work__toggle');
    expect(toggle?.querySelector('input[type="checkbox"]')).toBeTruthy();
  });

  it('reloads silently after save without showing the full-page loading state', () => {
    renderLoaded();
    loadUseCase.execute.mockClear();
    component.onRecordSaved({
      workRecord: {
        id: 1,
        cultivation_plan_id: 7,
        field_cultivation_id: null,
        task_schedule_item_id: 11,
        agricultural_task_id: null,
        name: '今日の作業',
        task_type: null,
        actual_date: '2026-06-25',
        amount: null,
        amount_unit: null,
        time_spent_minutes: null,
        notes: null,
        created_at: '2026-06-25',
        updated_at: '2026-06-25',
        task_schedule_item: null
      },
      mode: 'create-from-item'
    });

    expect(loadUseCase.execute).toHaveBeenCalled();
    expect(component.control.loading).toBe(false);
    expect(fixture.nativeElement.querySelector('.master-loading')).toBeNull();
  });

  it('shows recent ad-hoc feedback instead of empty state after unscheduled save', () => {
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      overdue: [],
      today: [],
      upcoming: []
    };
    fixture.detectChanges();

    component.onRecordSaved({
      workRecord: {
        id: 99,
        cultivation_plan_id: 7,
        field_cultivation_id: null,
        task_schedule_item_id: null,
        agricultural_task_id: null,
        name: '予定外除草',
        task_type: null,
        actual_date: '2026-06-25',
        amount: null,
        amount_unit: null,
        time_spent_minutes: null,
        notes: null,
        created_at: '2026-06-25',
        updated_at: '2026-06-25',
        task_schedule_item: null
      },
      mode: 'create-adhoc'
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-work__empty')).toBeNull();
    expect(fixture.nativeElement.querySelector('.plan-work__recent-adhoc')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('予定外除草');
  });

  it('highlights the completed schedule row after recording from item', () => {
    renderLoaded();
    component.onRecordSaved({
      workRecord: {
        id: 2,
        cultivation_plan_id: 7,
        field_cultivation_id: 10,
        task_schedule_item_id: 11,
        agricultural_task_id: null,
        name: '今日の作業',
        task_type: null,
        actual_date: '2026-06-25',
        amount: null,
        amount_unit: null,
        time_spent_minutes: null,
        notes: null,
        created_at: '2026-06-25',
        updated_at: '2026-06-25',
        task_schedule_item: null
      },
      mode: 'create-from-item'
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-work__row--highlight')).toBeTruthy();
  });

  it('shows error with retry button and reloads when retry is clicked', () => {
    fixture.detectChanges();
    component.control = {
      ...initialControl,
      loading: false,
      error: 'common.api_error.generic'
    };
    fixture.detectChanges();

    translate.setTranslation(
      'ja',
      {
        'common.api_error.generic': 'エラーが発生しました',
        'plans.work.retry': '再読み込み'
      },
      true
    );
    fixture.detectChanges();

    const retryBtn = fixture.nativeElement.querySelector('.plan-work__retry');
    expect(retryBtn).toBeTruthy();
    expect(retryBtn.textContent).toContain('再読み込み');

    loadUseCase.execute.mockClear();
    retryBtn.click();
    expect(loadUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 7 })
    );
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

  it('formats today and task dates for the active locale', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-06-25T12:00:00'));
    renderLoaded();
    vi.useRealTimers();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('2026年6月25日');
    expect(text).toContain('2026年6月17日');
    expect(text).not.toContain('2026-06-25');
    expect(text).not.toContain('2026-06-17');
  });

  it('shows sync banner and calls regenerate use case on retry', () => {
    renderLoaded();
    component.control = {
      ...loadedState,
      plan: {
        ...loadedState.plan!,
        task_schedule_sync_state: 'failed',
        task_schedule_sync_error: 'plans.task_schedules.sync_errors.agrr_unavailable'
      }
    };
    fixture.detectChanges();

    const banner = fixture.nativeElement.querySelector('app-task-schedule-sync-banner');
    expect(banner).toBeTruthy();
    component.regenerateTaskSchedule();
    expect(regenerateUseCase.execute).toHaveBeenCalledWith({ planId: 7 });
  });

  it('subscribes to task schedule sync cable on init', () => {
    component.ngOnInit();

    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(subscribeSyncUseCase.execute).toHaveBeenCalledWith({
      planId: 7,
      onSubscribed: expect.any(Function)
    });
    expect(loadUseCase.execute).toHaveBeenCalled();
  });
});

describe('PlanWorkComponent in locale labels', () => {
  let fixture: ComponentFixture<PlanWorkComponent>;
  let component: PlanWorkComponent;
  let translate: TranslateService;

  beforeEach(async () => {
    const loadUseCase = { execute: vi.fn() };
    const skipUseCase = { execute: vi.fn() };
    const createUseCase = { execute: vi.fn() };
    const regenerateUseCase = { execute: vi.fn() };
    const subscribeSyncUseCase = { execute: vi.fn() };
    const mockPresenter = {
      setView: vi.fn(),
      onSkipSuccessCallback: null,
      onRecordSavedCallback: null
    };
    const cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(PlanWorkComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadWorkDayListUseCase, useValue: loadUseCase },
          { provide: SkipTaskScheduleItemUseCase, useValue: skipUseCase },
          { provide: CreateWorkRecordUseCase, useValue: createUseCase },
          { provide: RegenerateTaskScheduleUseCase, useValue: regenerateUseCase },
          { provide: SubscribeTaskScheduleSyncUseCase, useValue: subscribeSyncUseCase },
          { provide: PlanWorkPresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanWorkComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        { provide: UndoToastService, useValue: { show: vi.fn() } },
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

    const emptyMessage = fixture.nativeElement.querySelector('.plan-work__empty-message');
    expect(emptyMessage?.textContent?.trim()).toBe('आज के लिए कोई कार्य निर्धारित नहीं');
    expect(emptyMessage?.textContent?.trim()).not.toBe('今日の予定はありません');
  });
});
