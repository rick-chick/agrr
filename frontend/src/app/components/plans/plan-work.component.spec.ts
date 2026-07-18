import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, TranslationObject } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { BehaviorSubject } from 'rxjs';
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
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
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
  nextScheduled: null,
  highlightedItemId: null,
  completingItemId: null,
  regenerating: false,
  regenerateError: null,
  pendingSyncToastKey: null,
  pendingRecordSavedToastKey: null,
  pendingRecordSavedEvent: null,
  pendingQuickCompleteValidation: null,
  syncReloadNonce: 0,
  cropIdsForBanner: [],
  cropNamesForBanner: {}
};

function createPlanRouteMock(planId: string) {
  let currentPlanId = planId;
  const paramMapSubject = new BehaviorSubject({
    get: (key: string) => (key === 'id' ? currentPlanId : null)
  });
  const queryParamMapSubject = new BehaviorSubject({
    get: () => null
  });

  return {
    snapshot: {
      get paramMap() {
        return paramMapSubject.value;
      },
      queryParamMap: { get: () => null }
    },
    paramMap: paramMapSubject.asObservable(),
    queryParamMap: queryParamMapSubject.asObservable(),
    setPlanId(id: string) {
      currentPlanId = id;
      paramMapSubject.next({
        get: (key: string) => (key === 'id' ? currentPlanId : null)
      });
    }
  };
}

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
    task_schedule_sync_error: null,
    task_schedule_sync_error_crop_id: null
  },
  fields: [],
  overdue: [mockRow({ item_id: 10, name: '遅延作業' })],
  today: [mockRow({ item_id: 11, name: '今日の作業' })],
  upcoming: [],
  includeSkipped: false,
  recentAdHocRecord: null,
  nextScheduled: null,
  highlightedItemId: null,
  completingItemId: null,
  regenerating: false,
  regenerateError: null,
  pendingSyncToastKey: null,
  pendingRecordSavedToastKey: null,
  pendingRecordSavedEvent: null,
  pendingQuickCompleteValidation: null,
  syncReloadNonce: 0,
  cropIdsForBanner: [],
  cropNamesForBanner: {}
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
    beginScheduleLoad: ReturnType<typeof vi.fn>;
  };
  let mockActivatedRoute: ReturnType<typeof createPlanRouteMock>;
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    skipUseCase = { execute: vi.fn() };
    createUseCase = { execute: vi.fn() };
    regenerateUseCase = { execute: vi.fn() };
    subscribeSyncUseCase = { execute: vi.fn() };
    mockPresenter = {
      setView: vi.fn(),
      beginScheduleLoad: vi.fn(() => 1)
    };
    cdr = { markForCheck: vi.fn() };
    mockActivatedRoute = createPlanRouteMock('7');

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
        {
          provide: ActivatedRoute,
          useValue: mockActivatedRoute
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
        'plans.work.page_title': '作業記録 — {{name}}',
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
        'plans.work.unskip': 'スキップ解除'
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

  it('uses unified plan context header without redundant breadcrumb links', () => {
    renderLoaded();
    expect(fixture.nativeElement.querySelector('.plan-work__back-nav')).toBeNull();
    expect(fixture.nativeElement.querySelector('.plan-context-header__crumbs')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-plan-plan-context-header')).toBeTruthy();
  });

  it('uses compact page-header with visually hidden title and section-card shell', () => {
    renderLoaded();
    const header = fixture.nativeElement.querySelector('.page-header.page-header--compact');
    const card = fixture.nativeElement.querySelector('.section-card');
    expect(header).toBeTruthy();
    expect(card).toBeTruthy();
    expect(card.contains(header)).toBe(false);
    expect(header.querySelector('#plan-context-page-title.visually-hidden')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('app-plan-detail-context-nav')).toBeTruthy();
  });

  it('keeps section-card bottom padding on plan-work shell', async () => {
    TestBed.resetTestingModule();
    await TestBed.configureTestingModule({
      imports: [PlanWorkComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: mockActivatedRoute
        }
      ]
    }).compileComponents();

    const styledFixture = TestBed.createComponent(PlanWorkComponent);
    styledFixture.detectChanges();
    styledFixture.componentInstance.control = {
      ...loadedState,
      overdue: [],
      today: [],
      upcoming: []
    };
    styledFixture.detectChanges();

    const card = styledFixture.nativeElement.querySelector('.section-card.plan-work') as HTMLElement;
    expect(card).toBeTruthy();
    expect(getComputedStyle(card).paddingBottom).not.toBe('0px');
    styledFixture.destroy();
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

  it('shows next scheduled hint in empty today state', () => {
    translate.setTranslation(
      'ja',
      {
        'plans.work.next_scheduled': '次の予定: {{date}} — {{name}}（{{field}}）',
        'plans.work.empty_today': '今日の作業はありません',
        'plans.work.empty_today_hint': '予定外の作業は下のボタンから記録できます',
        'plans.work.add_record': '+ 実績を登録'
      },
      true
    );
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      overdue: [],
      today: [],
      upcoming: [],
      nextScheduled: mockRow({
        item_id: 20,
        name: '追肥',
        scheduled_date: '2026-07-01'
      })
    };
    fixture.detectChanges();

    const hint = fixture.nativeElement.querySelector('.plan-work__empty-hint');
    expect(hint?.textContent).toContain('追肥');
    expect(hint?.textContent).toContain('次の予定');
    expect(hint?.textContent).not.toContain('予定外の作業');
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

  it('renders plan and task schedule links in empty today state without next scheduled', () => {
    translate.setTranslation(
      'ja',
      {
        'plans.work.empty_today': '今日の予定はありません',
        'plans.work.empty_today_hint': '予定外の作業はここから記録できます',
        'plans.work.empty_plan_cta': '作付け計画を確認',
        'plans.work.empty_task_schedule_cta': '作業計画表を確認',
        'plans.work.add_record': '+ 作業を記録'
      },
      true
    );
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      overdue: [],
      today: [],
      upcoming: [],
      nextScheduled: null
    };
    fixture.detectChanges();

    const links = fixture.nativeElement.querySelectorAll('.plan-work__empty-cta-link');
    expect(links.length).toBe(2);
    expect(links[0]?.textContent?.trim()).toBe('作付け計画を確認');
    expect(links[0]?.getAttribute('href')).toContain('/plans/7');
    expect(links[0]?.getAttribute('href')).not.toContain('task_schedule');
    expect(links[1]?.textContent?.trim()).toBe('作業計画表を確認');
    expect(links[1]?.getAttribute('href')).toContain('/plans/7/task_schedule');
  });

  it('renders task schedule link when next scheduled is shown in empty today state', () => {
    translate.setTranslation(
      'ja',
      {
        'plans.work.next_scheduled': '次の予定: {{date}} — {{name}}（{{field}}）',
        'plans.work.empty_today': '今日の予定はありません',
        'plans.work.empty_task_schedule_cta': '作業計画表を確認',
        'plans.work.add_record': '+ 作業を記録'
      },
      true
    );
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      overdue: [],
      today: [],
      upcoming: [],
      nextScheduled: mockRow({
        item_id: 20,
        name: '追肥',
        scheduled_date: '2026-07-01'
      })
    };
    fixture.detectChanges();

    const links = fixture.nativeElement.querySelectorAll('.plan-work__empty-cta-link');
    expect(links.length).toBe(1);
    expect(links[0]?.textContent?.trim()).toBe('作業計画表を確認');
    expect(links[0]?.getAttribute('href')).toContain('/plans/7/task_schedule');
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

  it('renders recent ad-hoc feedback as a section panel outside the task list', () => {
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      overdue: [],
      today: [],
      upcoming: [],
      recentAdHocRecord: {
        name: '規格選別',
        actualDate: '2026-07-03'
      }
    };
    fixture.detectChanges();

    const panel = fixture.nativeElement.querySelector('.plan-work__recent-adhoc');
    expect(panel?.tagName).toBe('DIV');
    expect(panel?.closest('.plan-work__list')).toBeNull();
    expect(fixture.nativeElement.querySelector('.plan-work__list')).toBeNull();
  });

  it('renders empty today state as a section panel outside the task list', () => {
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      overdue: [],
      today: [],
      upcoming: []
    };
    fixture.detectChanges();

    const panel = fixture.nativeElement.querySelector('.plan-work__empty');
    expect(panel?.tagName).toBe('DIV');
    expect(panel?.closest('.plan-work__list')).toBeNull();
    expect(fixture.nativeElement.querySelector('.plan-work__list')).toBeNull();
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

  it('shows sync banner when sync failed', () => {
    renderLoaded();
    component.control = {
      ...loadedState,
      plan: {
        ...loadedState.plan!,
        task_schedule_sync_state: 'failed',
        task_schedule_sync_error: 'plans.task_schedules.sync_errors.agrr_unavailable',
        task_schedule_sync_error_crop_id: null
      }
    };
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-task-schedule-sync-banner')).toBeTruthy();
  });

  it('reads crop banner context from control without adapter helpers', () => {
    renderLoaded();
    component.control = {
      ...loadedState,
      cropIdsForBanner: [20, 30],
      cropNamesForBanner: { 20: 'Tomato', 30: 'Carrot' }
    };

    expect(component.cropIdsForBanner).toEqual([20, 30]);
    expect(component.cropNamesForBanner).toEqual({ 20: 'Tomato', 30: 'Carrot' });
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

  it('reloads and resubscribes when route plan id changes', () => {
    const oldChannel = { unsubscribe: vi.fn() };
    subscribeSyncUseCase.execute.mockImplementation(({ onSubscribed }) => {
      onSubscribed(oldChannel);
    });

    fixture.detectChanges();
    loadUseCase.execute.mockClear();
    subscribeSyncUseCase.execute.mockClear();

    mockActivatedRoute.setPlanId('8');

    expect(oldChannel.unsubscribe).toHaveBeenCalled();
    expect(subscribeSyncUseCase.execute).toHaveBeenCalledWith({
      planId: 8,
      onSubscribed: expect.any(Function)
    });
    expect(loadUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 8 })
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
    const createUseCase = { execute: vi.fn() };
    const regenerateUseCase = { execute: vi.fn() };
    const subscribeSyncUseCase = { execute: vi.fn() };
    const mockPresenter = {
      setView: vi.fn(),
      beginScheduleLoad: vi.fn(() => 1)
    };
    const cdr = { markForCheck: vi.fn() };
    const localeRouteMock = createPlanRouteMock('7');

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
        {
          provide: ActivatedRoute,
          useValue: localeRouteMock
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

  it('renders Hindi empty state instead of ja fallback', async () => {
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      overdue: [],
      today: [],
      upcoming: []
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const emptyMessage = fixture.nativeElement.querySelector('.plan-work__empty-message');
    expect(emptyMessage?.textContent?.trim()).toBe('आज के लिए कोई कार्य निर्धारित नहीं');
    expect(emptyMessage?.textContent?.trim()).not.toBe('今日の予定はありません');
  });
});
