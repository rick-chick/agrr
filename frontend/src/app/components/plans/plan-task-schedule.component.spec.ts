import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { RegenerateTaskScheduleUseCase } from '../../usecase/plans/regenerate-task-schedule.usecase';
import { SubscribeTaskScheduleSyncUseCase } from '../../usecase/plans/subscribe-task-schedule-sync.usecase';
import { PlanTaskSchedulePresenter } from '../../usecase/plans/plan-task-schedule.providers';
import { PlanTaskScheduleComponent } from './plan-task-schedule.component';
import type { PlanTaskScheduleViewState } from './plan-task-schedule.view';
import type { TaskScheduleResponse } from '../../models/plans/task-schedule';

const loadedSchedule: TaskScheduleResponse = {
  plan: {
    id: 7,
    name: 'Main Plan',
    status: 'completed',
    planning_start_date: '2026-01-01',
    planning_end_date: '2026-12-31',
    timeline_generated_at: '2026-06-01T00:00:00Z',
    timeline_generated_at_display: '2026-06-01',
    task_schedule_sync_state: 'ready',
    task_schedule_sync_error: null,
    task_schedule_sync_error_crop_id: null
  },
  week: {
    start_date: '2026-06-01',
    end_date: '2026-06-07',
    label: '2026-06-01',
    days: []
  },
  milestones: [],
  fields: [],
  labels: {},
  minimap: {
    start_date: '2026-05-25',
    end_date: '2026-06-14',
    weeks: [
      { start_date: '2026-06-01', label: '2026-06-01', task_count: 5, density: 'medium', month_key: '2026-06' }
    ]
  }
};

const loadedState: PlanTaskScheduleViewState = {
  loading: false,
  error: null,
  schedule: loadedSchedule,
  regenerating: false,
  regenerateError: null,
  pendingSyncToastKey: null,
  syncReloadNonce: 0
};

describe('PlanTaskScheduleComponent', () => {
  let component: PlanTaskScheduleComponent;
  let fixture: ComponentFixture<PlanTaskScheduleComponent>;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let regenerateUseCase: { execute: ReturnType<typeof vi.fn> };
  let subscribeSyncUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: {
    setView: ReturnType<typeof vi.fn>;
  };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };
  let mockActivatedRoute: {
    snapshot: {
      paramMap: { get: ReturnType<typeof vi.fn> };
      queryParamMap: { get: ReturnType<typeof vi.fn> };
    };
  };

  beforeEach(async () => {
    loadUseCase = { execute: vi.fn() };
    regenerateUseCase = { execute: vi.fn() };
    subscribeSyncUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };
    mockActivatedRoute = {
      snapshot: {
        paramMap: { get: vi.fn(() => '7') },
        queryParamMap: { get: vi.fn(() => null) }
      }
    };

    TestBed.overrideComponent(PlanTaskScheduleComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPlanTaskScheduleUseCase, useValue: loadUseCase },
          { provide: RegenerateTaskScheduleUseCase, useValue: regenerateUseCase },
          { provide: SubscribeTaskScheduleSyncUseCase, useValue: subscribeSyncUseCase },
          { provide: PlanTaskSchedulePresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr },
          { provide: ActivatedRoute, useValue: mockActivatedRoute }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanTaskScheduleComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    fixture = TestBed.createComponent(PlanTaskScheduleComponent);
    component = fixture.componentInstance;
  });

  afterEach(() => {
    fixture.destroy();
    vi.restoreAllMocks();
  });

  it('implements View control getter/setter', () => {
    const state: PlanTaskScheduleViewState = {
      loading: false,
      error: null,
      schedule: null,
      regenerating: false,
      regenerateError: null,
      pendingSyncToastKey: null,
      syncReloadNonce: 0
    
    };
    component.control = state;
    expect(component.control).toEqual(state);
  });

  it('uses the unified plan context header with back link and cross-context action', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    const header = fixture.nativeElement.querySelector('.plan-context-header');
    expect(header).toBeTruthy();
    const crumbs = header.querySelector('.plan-context-header__crumbs');
    expect(crumbs?.querySelector('.plan-context-header__back')?.textContent).toContain('Plan list');
    expect(crumbs?.querySelector('.plan-context-header__forward')?.textContent).toContain('Work log');
    expect(header.querySelector('.plan-context-header__plan-name')?.textContent).toContain('Main Plan');
    const workbenchTab = header.querySelector('app-plan-detail-context-nav .plan-context-nav__link');
    expect(workbenchTab?.getAttribute('href')).toContain('/plans/7');
  });

  it('renders page intro when schedule is loaded', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    const intro = fixture.nativeElement.querySelector('.plan-task-schedule__page-intro');
    expect(intro).toBeTruthy();
    expect(intro?.textContent).toContain('Tasks and dates are calculated from your planting plan cultivation periods');
    expect(intro?.textContent).not.toContain('plans.task_schedules.page_intro');
  });

  it('shows empty_ready_no_fields hint when sync is ready and fields are empty', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    const hint = fixture.nativeElement.querySelector('.plan-work__empty-hint');
    expect(hint?.textContent).toContain('no fields to display');
    expect(hint?.textContent).not.toContain('Add crops to your plan');
  });

  it('shows empty_hint when sync is never and fields are empty', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      schedule: {
        ...loadedSchedule,
        plan: {
          ...loadedSchedule.plan,
          task_schedule_sync_state: 'never',
          task_schedule_sync_error: null,
          task_schedule_sync_error_crop_id: null
        }
      }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const hint = fixture.nativeElement.querySelector('.plan-work__empty-hint');
    expect(hint?.textContent).toContain('Add crops to your plan to generate task schedules');
  });

  it('does not show empty hint when sync failed', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      schedule: {
        ...loadedSchedule,
        plan: {
          ...loadedSchedule.plan,
          task_schedule_sync_state: 'failed',
          task_schedule_sync_error: 'generic',
          task_schedule_sync_error_crop_id: null
        }
      }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.plan-work__empty-hint')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-task-schedule-sync-banner')).toBeTruthy();
  });

  it('renders empty schedule message when fields are empty', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('No task schedule has been generated yet.');
    expect(text).not.toContain('plans.task_schedules.no_schedules');
    expect(fixture.nativeElement.querySelector('.plan-work__empty')).toBeTruthy();
  });

  it('shows regenerate CTA in banner when sync never generated', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      schedule: {
        ...loadedSchedule,
        plan: {
          ...loadedSchedule.plan,
          task_schedule_sync_state: 'never',
          task_schedule_sync_error: null,
    task_schedule_sync_error_crop_id: null
        }
      }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.plan-work__empty-cta')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-task-schedule-sync-banner')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.task-schedule-sync-banner__retry')?.textContent).toContain(
      'Regenerate task schedules'
    );
  });

  it('renders plan context navigation in header before schedule content', async () => {
    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    const header = fixture.nativeElement.querySelector('.page-header.page-header--compact');
    const nav = fixture.nativeElement.querySelector('app-plan-detail-context-nav');
    expect(header).toBeTruthy();
    expect(nav).toBeTruthy();
    expect(header!.compareDocumentPosition(nav!) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    const pageTitle = fixture.nativeElement.querySelector('#plan-context-page-title');
    expect(pageTitle).toBeTruthy();
    expect(pageTitle?.classList.contains('visually-hidden')).toBe(true);
    expect(fixture.nativeElement.querySelector('.plan-context-header__identity')).toBeTruthy();
  });

  it('does not show empty-state CTA duplicating the workbench tab', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('.plan-work__empty-cta-link')).toBeNull();
  });

  it('renders translated API error instead of raw i18n key', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      loading: false,
      error: 'common.api_error.generic',
      schedule: null,
      regenerating: false,
      regenerateError: null,
      pendingSyncToastKey: null,
      syncReloadNonce: 0
    
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const alert = fixture.nativeElement.querySelector('.page-alert-error');
    expect(alert?.textContent?.trim()).not.toBe('common.api_error.generic');
  });

  it('shows error with retry button and reloads when retry is clicked', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        ...(en as TranslationObject),
        'common.api_error.generic': 'An error occurred',
        'plans.work.retry': 'Reload'
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      loading: false,
      error: 'common.api_error.generic',
      schedule: null,
      regenerating: false,
      regenerateError: null,
      pendingSyncToastKey: null,
      syncReloadNonce: 0
    
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const retryBtn = fixture.nativeElement.querySelector('.plan-work__retry');
    expect(retryBtn).toBeTruthy();
    expect(retryBtn.textContent).toContain('Reload');

    loadUseCase.execute.mockClear();
    retryBtn.click();
    expect(loadUseCase.execute).toHaveBeenCalledWith({ planId: 7, scope: 'plan' });
  });

  it('subscribes to task schedule sync cable on init', () => {
    component.ngOnInit();

    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
    expect(subscribeSyncUseCase.execute).toHaveBeenCalledWith({
      planId: 7,
      onSubscribed: expect.any(Function)
    });
    expect(loadUseCase.execute).toHaveBeenCalledWith({ planId: 7, scope: 'plan' });
  });

  it('shows ready regenerate details when sync is ready and schedule has fields', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      schedule: {
        ...loadedSchedule,
        fields: [
          {
            id: 1,
            name: 'Field A',
            crop_name: 'Tomato',
            area_sqm: 100,
            field_cultivation_id: 10,
            crop_id: 20,
            task_options: [],
            schedules: { general: [], fertilizer: [], unscheduled: [] }
          }
        ]
      }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const details = fixture.nativeElement.querySelector('.plan-task-schedule__regenerate-details');
    expect(details).toBeTruthy();
    const button = details.querySelector('.plan-task-schedule__regenerate-button');
    expect(button?.textContent).toContain('Regenerate task schedules');

    regenerateUseCase.execute.mockClear();
    button.click();
    expect(regenerateUseCase.execute).toHaveBeenCalledWith({ planId: 7 });
  });

  it('renders week nav when schedule has fields', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        ...(en as TranslationObject),
        'plans.task_schedules.view_mode_plan': 'List',
        'plans.task_schedules.view_mode_week': 'Week'
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      schedule: {
        ...loadedSchedule,
        fields: [
          {
            id: 1,
            name: 'Field A',
            crop_name: 'Tomato',
            area_sqm: 100,
            field_cultivation_id: 10,
            crop_id: 20,
            task_options: [],
            schedules: { general: [], fertilizer: [], unscheduled: [] }
          }
        ]
      }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('app-task-schedule-week-nav')).toBeTruthy();
  });

  it('reloads with week scope when switching to week mode', () => {
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      schedule: {
        ...loadedSchedule,
        fields: [
          {
            id: 1,
            name: 'Field A',
            crop_name: 'Tomato',
            area_sqm: 100,
            field_cultivation_id: 10,
            crop_id: 20,
            task_options: [],
            schedules: { general: [], fertilizer: [], unscheduled: [] }
          }
        ]
      }
    };
    fixture.detectChanges();

    loadUseCase.execute.mockClear();
    component.onViewModeChange('week');

    expect(component.viewMode).toBe('week');
    expect(loadUseCase.execute).toHaveBeenCalledWith({
      planId: 7,
      scope: 'week',
      weekStart: '2026-06-01'
    });
  });

  it('reloads with week_start when week navigation changes', () => {
    fixture.detectChanges();
    component.viewMode = 'week';
    component.currentWeekStart = '2026-06-01';
    component.control = {
      ...loadedState,
      schedule: {
        ...loadedSchedule,
        fields: [
          {
            id: 1,
            name: 'Field A',
            crop_name: 'Tomato',
            area_sqm: 100,
            field_cultivation_id: 10,
            crop_id: 20,
            task_options: [],
            schedules: { general: [], fertilizer: [], unscheduled: [] }
          }
        ]
      }
    };
    fixture.detectChanges();

    loadUseCase.execute.mockClear();
    component.onWeekChange('2026-06-08');

    expect(component.currentWeekStart).toBe('2026-06-08');
    expect(loadUseCase.execute).toHaveBeenCalledWith({
      planId: 7,
      scope: 'week',
      weekStart: '2026-06-08'
    });
  });

  it('reloads current week without weekStart when today is requested', () => {
    fixture.detectChanges();
    component.viewMode = 'week';
    component.currentWeekStart = '2026-05-25';
    fixture.detectChanges();

    loadUseCase.execute.mockClear();
    component.onWeekToday();

    expect(component.currentWeekStart).toBeNull();
    expect(loadUseCase.execute).toHaveBeenCalledWith({
      planId: 7,
      scope: 'week'
    });
  });

  it('preserves week scope on silent reload', () => {
    fixture.detectChanges();
    component.viewMode = 'week';
    component.currentWeekStart = '2026-06-01';
    fixture.detectChanges();

    loadUseCase.execute.mockClear();
    component.reload({ silent: true });

    expect(loadUseCase.execute).toHaveBeenCalledWith({
      planId: 7,
      scope: 'week',
      weekStart: '2026-06-01'
    });
  });

  it('passes fieldCultivationId to use case when query param is set', async () => {
    TestBed.resetTestingModule();
    loadUseCase = { execute: vi.fn() };
    regenerateUseCase = { execute: vi.fn() };
    subscribeSyncUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(PlanTaskScheduleComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPlanTaskScheduleUseCase, useValue: loadUseCase },
          { provide: RegenerateTaskScheduleUseCase, useValue: regenerateUseCase },
          { provide: SubscribeTaskScheduleSyncUseCase, useValue: subscribeSyncUseCase },
          { provide: PlanTaskSchedulePresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr },
          {
            provide: ActivatedRoute,
            useValue: {
              snapshot: {
                paramMap: { get: vi.fn(() => '7') },
                queryParamMap: {
                  get: vi.fn((key: string) => (key === 'field_cultivation_id' ? '42' : null))
                }
              }
            }
          }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanTaskScheduleComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const filteredFixture = TestBed.createComponent(PlanTaskScheduleComponent);
    filteredFixture.componentInstance.ngOnInit();

    expect(loadUseCase.execute).toHaveBeenCalledWith({
      planId: 7,
      scope: 'plan',
      fieldCultivationId: 42
    });
  });

  it('shows filter navigation when field_cultivation_id query param is set', async () => {
    TestBed.resetTestingModule();
    loadUseCase = { execute: vi.fn() };
    regenerateUseCase = { execute: vi.fn() };
    subscribeSyncUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(PlanTaskScheduleComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPlanTaskScheduleUseCase, useValue: loadUseCase },
          { provide: RegenerateTaskScheduleUseCase, useValue: regenerateUseCase },
          { provide: SubscribeTaskScheduleSyncUseCase, useValue: subscribeSyncUseCase },
          { provide: PlanTaskSchedulePresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr },
          {
            provide: ActivatedRoute,
            useValue: {
              snapshot: {
                paramMap: { get: vi.fn(() => '7') },
                queryParamMap: {
                  get: vi.fn((key: string) => (key === 'field_cultivation_id' ? '42' : null))
                }
              }
            }
          }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanTaskScheduleComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    const filteredFixture = TestBed.createComponent(PlanTaskScheduleComponent);
    filteredFixture.detectChanges();
    filteredFixture.componentInstance.control = {
      ...loadedState,
      schedule: {
        ...loadedSchedule,
        fields: [
          {
            id: 1,
            name: 'Field A',
            crop_name: 'Tomato',
            area_sqm: 100,
            field_cultivation_id: 42,
            crop_id: 1,
            task_options: [],
            schedules: { general: [], fertilizer: [], unscheduled: [] }
          }
        ]
      }
    };
    filteredFixture.detectChanges();
    await filteredFixture.whenStable();

    const nav = filteredFixture.nativeElement.querySelector('.plan-task-schedule__filter-nav');
    expect(nav).toBeTruthy();
    const links = nav.querySelectorAll('.plan-task-schedule__filter-link');
    expect(links.length).toBe(2);
    expect(links[0]?.getAttribute('href')).toContain('/plans/7/task_schedule');
    expect(links[0]?.textContent).toContain('View all fields');
    expect(links[1]?.getAttribute('href')).toContain('/plans/7');
    expect(links[1]?.textContent).toContain('Back to cropping plan');
  });
});

describe('PlanTaskScheduleComponent locale labels', () => {
  let fixture: ComponentFixture<PlanTaskScheduleComponent>;

  async function setupLocale(localeId: 'ja' | 'en' | 'in'): Promise<void> {
    loadUseCase = { execute: vi.fn() };
    regenerateUseCase = { execute: vi.fn() };
    subscribeSyncUseCase = { execute: vi.fn() };
    mockPresenter = { setView: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    TestBed.resetTestingModule();
    TestBed.overrideComponent(PlanTaskScheduleComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPlanTaskScheduleUseCase, useValue: loadUseCase },
          { provide: RegenerateTaskScheduleUseCase, useValue: regenerateUseCase },
          { provide: SubscribeTaskScheduleSyncUseCase, useValue: subscribeSyncUseCase },
          { provide: PlanTaskSchedulePresenter, useValue: mockPresenter },
          { provide: ChangeDetectorRef, useValue: cdr },
          {
            provide: ActivatedRoute,
            useValue: {
              snapshot: {
                paramMap: { get: vi.fn(() => '7') },
                queryParamMap: { get: vi.fn(() => null) }
              }
            }
          }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanTaskScheduleComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('ja', ja as TranslationObject, true);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setTranslation('in', inLocale as TranslationObject, true);
    translate.setDefaultLang('ja');
    translate.use(localeId);

    fixture = TestBed.createComponent(PlanTaskScheduleComponent);
    fixture.detectChanges();
    fixture.componentInstance.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();
  }

  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let regenerateUseCase: { execute: ReturnType<typeof vi.fn> };
  let subscribeSyncUseCase: { execute: ReturnType<typeof vi.fn> };
  let mockPresenter: {
    setView: ReturnType<typeof vi.fn>;
  };
  let cdr: { markForCheck: ReturnType<typeof vi.fn> };

  afterEach(() => {
    fixture?.destroy();
    vi.restoreAllMocks();
  });

  it('renders Japanese labels instead of raw i18n keys', async () => {
    await setupLocale('ja');

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).not.toContain('計画詳細へ');
    expect(fixture.nativeElement.querySelector('.plan-context-header__crumbs')).toBeTruthy();
    expect(text).toContain('計画一覧へ');
    expect(text).toContain('作業記録へ');
    expect(text).toContain('作業予定がまだ生成されていません。');
    expect(text).not.toContain('plans.task_schedules.');
  });

  it('renders English labels instead of raw i18n keys', async () => {
    await setupLocale('en');

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).not.toContain('Plan details');
    expect(fixture.nativeElement.querySelector('.plan-context-header__crumbs')).toBeTruthy();
    expect(text).toContain('Plan list');
    expect(text).toContain('Work log');
    expect(text).toContain('No task schedule has been generated yet.');
    expect(text).not.toContain('plans.task_schedules.');
  });

  it('renders Hindi labels instead of raw i18n keys', async () => {
    await setupLocale('in');

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).not.toContain('योजना विवरण');
    expect(fixture.nativeElement.querySelector('.plan-context-header__crumbs')).toBeTruthy();
    expect(text).toContain('योजना सूची');
    expect(text).toContain('कार्य लॉग');
    expect(text).toContain('अभी तक कोई कार्य अनुसूची नहीं बनाई गई है।');
    expect(text).not.toContain('plans.task_schedules.');
  });
});
