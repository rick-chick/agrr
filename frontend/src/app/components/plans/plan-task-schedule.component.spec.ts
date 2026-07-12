import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
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
import { localTodayIso } from '../../core/local-today';

function shiftIsoDate(isoDate: string, dayDelta: number): string {
  const [year, month, day] = isoDate.split('-').map(Number);
  const shifted = new Date(year, month - 1, day + dayDelta);
  const y = shifted.getFullYear();
  const m = String(shifted.getMonth() + 1).padStart(2, '0');
  const d = String(shifted.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

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
  syncReloadNonce: 0,
  fromDate: localTodayIso(),
  fieldCultivationFilterId: null,
  monthGroups: [],
  fieldFilterOptions: [],
  cropIdsForBanner: [],
  cropNamesForBanner: {}
};

function setScheduleControl(
  component: PlanTaskScheduleComponent,
  presenter: PlanTaskSchedulePresenter,
  control: PlanTaskScheduleViewState,
  filters?: { fromDate?: string; fieldCultivationFilterId?: number | null }
): void {
  component.control = control;
  if (control.schedule) {
    presenter.applyClientFilters(
      filters?.fromDate ?? control.fromDate,
      filters?.fieldCultivationFilterId ?? control.fieldCultivationFilterId
    );
  }
}

describe('PlanTaskScheduleComponent', () => {
  let component: PlanTaskScheduleComponent;
  let fixture: ComponentFixture<PlanTaskScheduleComponent>;
  let loadUseCase: { execute: ReturnType<typeof vi.fn> };
  let regenerateUseCase: { execute: ReturnType<typeof vi.fn> };
  let subscribeSyncUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: PlanTaskSchedulePresenter;
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
          PlanTaskSchedulePresenter,
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
    presenter = fixture.debugElement.injector.get(PlanTaskSchedulePresenter);
  });

  afterEach(() => {
    fixture?.destroy();
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
      syncReloadNonce: 0,
      fromDate: localTodayIso(),
      fieldCultivationFilterId: null,
      monthGroups: [],
      fieldFilterOptions: [],
      cropIdsForBanner: [],
      cropNamesForBanner: {}
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

  it('does not render page intro when schedule is loaded', async () => {
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

    expect(fixture.nativeElement.querySelector('.plan-task-schedule__page-intro')).toBeNull();
  });

  it('renders schedule toolbar with month list only', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');
    const today = localTodayIso();

    fixture.detectChanges();
    setScheduleControl(component, presenter, {
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
            schedules: {
              general: [
                {
                  item_id: 1,
                  name: 'Weeding',
                  task_type: 'general',
                  category: 'general',
                  scheduled_date: today,
                  priority: 1,
                  source: 'blueprint',
                  weather_dependency: 'low',
                  time_per_sqm: '0',
                  amount: '',
                  amount_unit: '',
                  status: 'planned',
                  agricultural_task_id: 1,
                  field_cultivation_id: 10,
                  completed: false,
                  work_records: [],
                  details: {
                    stage: { name: 'Stage', order: 1 },
                    gdd: { trigger: '100', tolerance: '10' },
                    priority: 1,
                    weather_dependency: 'low',
                    time_per_sqm: '0',
                    amount: '',
                    amount_unit: '',
                    source: 'blueprint',
                    master: null,
                    history: { rescheduled_at: null, cancelled_at: null }
                  },
                  badge: { type: 'planned' }
                }
              ],
              fertilizer: [],
              unscheduled: []
            }
          }
        ]
      }
    }, { fromDate: today });
    fixture.detectChanges();
    await fixture.whenStable();

    const toolbar = fixture.nativeElement.querySelector('.plan-task-schedule__toolbar');
    expect(toolbar).toBeTruthy();
    expect(toolbar?.querySelector('app-task-schedule-week-nav')).toBeNull();
    expect(toolbar?.querySelector('.plan-task-schedule__meta')).toBeTruthy();
    expect(toolbar?.querySelector('.plan-task-schedule__generated-at')?.textContent).toContain('Generated');
    expect(toolbar?.querySelector('.plan-task-schedule__summary')?.textContent).toContain('field');
    expect(fixture.nativeElement.querySelector('app-task-schedule-month-list')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('app-task-schedule-timeline')).toBeNull();
    expect(fixture.nativeElement.textContent).toContain('Weeding');
  });

  it('defaults fromDate filter to local today when query param is absent', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');
    const today = localTodayIso();
    const pastDate = shiftIsoDate(today, -5);

    fixture.detectChanges();
    expect(component.fromDate).toBe(today);
    setScheduleControl(component, presenter, {
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
            schedules: {
              general: [
                {
                  item_id: 1,
                  name: 'Past task',
                  task_type: 'general',
                  category: 'general',
                  scheduled_date: pastDate,
                  priority: 1,
                  source: 'blueprint',
                  weather_dependency: 'low',
                  time_per_sqm: '0',
                  amount: '',
                  amount_unit: '',
                  status: 'planned',
                  agricultural_task_id: 1,
                  field_cultivation_id: 10,
                  completed: false,
                  work_records: [],
                  details: {
                    stage: { name: 'Stage', order: 1 },
                    gdd: { trigger: '100', tolerance: '10' },
                    priority: 1,
                    weather_dependency: 'low',
                    time_per_sqm: '0',
                    amount: '',
                    amount_unit: '',
                    source: 'blueprint',
                    master: null,
                    history: { rescheduled_at: null, cancelled_at: null }
                  },
                  badge: { type: 'planned' }
                },
                {
                  item_id: 2,
                  name: 'Today task',
                  task_type: 'general',
                  category: 'general',
                  scheduled_date: today,
                  priority: 1,
                  source: 'blueprint',
                  weather_dependency: 'low',
                  time_per_sqm: '0',
                  amount: '',
                  amount_unit: '',
                  status: 'planned',
                  agricultural_task_id: 1,
                  field_cultivation_id: 10,
                  completed: false,
                  work_records: [],
                  details: {
                    stage: { name: 'Stage', order: 1 },
                    gdd: { trigger: '100', tolerance: '10' },
                    priority: 1,
                    weather_dependency: 'low',
                    time_per_sqm: '0',
                    amount: '',
                    amount_unit: '',
                    source: 'blueprint',
                    master: null,
                    history: { rescheduled_at: null, cancelled_at: null }
                  },
                  badge: { type: 'planned' }
                }
              ],
              fertilizer: [],
              unscheduled: []
            }
          }
        ]
      }
    }, { fromDate: today });
    fixture.detectChanges();
    await fixture.whenStable();

    const dateInput = fixture.nativeElement.querySelector(
      '.plan-task-schedule__filters input[type="date"]'
    ) as HTMLInputElement;
    expect(dateInput?.value).toBe(today);
    expect(fixture.nativeElement.textContent).toContain('Today task');
    expect(fixture.nativeElement.textContent).not.toContain('Past task');
  });

  it('uses from_date query param for the date filter', async () => {
    TestBed.resetTestingModule();
    loadUseCase = { execute: vi.fn() };
    regenerateUseCase = { execute: vi.fn() };
    subscribeSyncUseCase = { execute: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(PlanTaskScheduleComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPlanTaskScheduleUseCase, useValue: loadUseCase },
          { provide: RegenerateTaskScheduleUseCase, useValue: regenerateUseCase },
          { provide: SubscribeTaskScheduleSyncUseCase, useValue: subscribeSyncUseCase },
          PlanTaskSchedulePresenter,
          { provide: ChangeDetectorRef, useValue: cdr },
          {
            provide: ActivatedRoute,
            useValue: {
              snapshot: {
                paramMap: { get: vi.fn(() => '7') },
                queryParamMap: {
                  get: vi.fn((key: string) => (key === 'from_date' ? '2026-06-01' : null))
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

    const fromDateFixture = TestBed.createComponent(PlanTaskScheduleComponent);
    const fromDatePresenter = fromDateFixture.debugElement.injector.get(PlanTaskSchedulePresenter);
    fromDateFixture.detectChanges();
    setScheduleControl(fromDateFixture.componentInstance, fromDatePresenter, {
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
            schedules: {
              general: [
                {
                  item_id: 1,
                  name: 'Past task',
                  task_type: 'general',
                  category: 'general',
                  scheduled_date: '2026-06-01',
                  priority: 1,
                  source: 'blueprint',
                  weather_dependency: 'low',
                  time_per_sqm: '0',
                  amount: '',
                  amount_unit: '',
                  status: 'planned',
                  agricultural_task_id: 1,
                  field_cultivation_id: 10,
                  completed: false,
                  work_records: [],
                  details: {
                    stage: { name: 'Stage', order: 1 },
                    gdd: { trigger: '100', tolerance: '10' },
                    priority: 1,
                    weather_dependency: 'low',
                    time_per_sqm: '0',
                    amount: '',
                    amount_unit: '',
                    source: 'blueprint',
                    master: null,
                    history: { rescheduled_at: null, cancelled_at: null }
                  },
                  badge: { type: 'planned' }
                },
                {
                  item_id: 2,
                  name: 'Later task',
                  task_type: 'general',
                  category: 'general',
                  scheduled_date: '2026-06-15',
                  priority: 1,
                  source: 'blueprint',
                  weather_dependency: 'low',
                  time_per_sqm: '0',
                  amount: '',
                  amount_unit: '',
                  status: 'planned',
                  agricultural_task_id: 1,
                  field_cultivation_id: 10,
                  completed: false,
                  work_records: [],
                  details: {
                    stage: { name: 'Stage', order: 1 },
                    gdd: { trigger: '100', tolerance: '10' },
                    priority: 1,
                    weather_dependency: 'low',
                    time_per_sqm: '0',
                    amount: '',
                    amount_unit: '',
                    source: 'blueprint',
                    master: null,
                    history: { rescheduled_at: null, cancelled_at: null }
                  },
                  badge: { type: 'planned' }
                }
              ],
              fertilizer: [],
              unscheduled: []
            }
          }
        ]
      }
    }, { fromDate: '2026-06-01' });
    fromDateFixture.detectChanges();
    await fromDateFixture.whenStable();

    const dateInput = fromDateFixture.nativeElement.querySelector(
      '.plan-task-schedule__filters input[type="date"]'
    ) as HTMLInputElement;
    expect(dateInput?.value).toBe('2026-06-01');
    expect(fromDateFixture.nativeElement.textContent).toContain('Past task');
    expect(fromDateFixture.nativeElement.textContent).toContain('Later task');
  });

  it('updates from_date query param when the date filter changes', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');
    const router = TestBed.inject(Router);
    const navigateSpy = vi.spyOn(router, 'navigate').mockResolvedValue(true);

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

    component.onFromDateChange('2026-07-01');

    expect(navigateSpy).toHaveBeenCalledWith(
      [],
      expect.objectContaining({
        queryParams: { from_date: '2026-07-01' },
        queryParamsHandling: 'merge',
        replaceUrl: true
      })
    );
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
      ...loadedState,
      loading: false,
      error: 'common.api_error.generic',
      schedule: null
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
      ...loadedState,
      loading: false,
      error: 'common.api_error.generic',
      schedule: null
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const retryBtn = fixture.nativeElement.querySelector('.plan-work__retry');
    expect(retryBtn).toBeTruthy();
    expect(retryBtn.textContent).toContain('Reload');

    loadUseCase.execute.mockClear();
    retryBtn.click();
    expect(loadUseCase.execute).toHaveBeenCalledWith({ planId: 7 });
  });

  it('subscribes to task schedule sync cable on init', () => {
    const setViewSpy = vi.spyOn(presenter, 'setView');

    component.ngOnInit();

    expect(setViewSpy).toHaveBeenCalledWith(component);
    expect(subscribeSyncUseCase.execute).toHaveBeenCalledWith({
      planId: 7,
      onSubscribed: expect.any(Function)
    });
    expect(loadUseCase.execute).toHaveBeenCalledWith({ planId: 7 });
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

  it('filters month list rows by field cultivation id from query param', async () => {
    TestBed.resetTestingModule();
    loadUseCase = { execute: vi.fn() };
    regenerateUseCase = { execute: vi.fn() };
    subscribeSyncUseCase = { execute: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(PlanTaskScheduleComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPlanTaskScheduleUseCase, useValue: loadUseCase },
          { provide: RegenerateTaskScheduleUseCase, useValue: regenerateUseCase },
          { provide: SubscribeTaskScheduleSyncUseCase, useValue: subscribeSyncUseCase },
          PlanTaskSchedulePresenter,
          { provide: ChangeDetectorRef, useValue: cdr },
          {
            provide: ActivatedRoute,
            useValue: {
              snapshot: {
                paramMap: { get: vi.fn(() => '7') },
                queryParamMap: {
                  get: vi.fn((key: string) => {
                    if (key === 'field_cultivation_id') return '42';
                    if (key === 'from_date') return '2026-01-01';
                    return null;
                  })
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
    const filteredPresenter = filteredFixture.debugElement.injector.get(PlanTaskSchedulePresenter);
    filteredFixture.detectChanges();
    setScheduleControl(filteredFixture.componentInstance, filteredPresenter, {
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
            schedules: {
              general: [
                {
                  item_id: 1,
                  name: 'North task',
                  task_type: 'general',
                  category: 'general',
                  scheduled_date: '2026-06-10',
                  priority: 1,
                  source: 'blueprint',
                  weather_dependency: 'low',
                  time_per_sqm: '0',
                  amount: '',
                  amount_unit: '',
                  status: 'planned',
                  agricultural_task_id: 1,
                  field_cultivation_id: 42,
                  completed: false,
                  work_records: [],
                  details: {
                    stage: { name: 'Stage', order: 1 },
                    gdd: { trigger: '100', tolerance: '10' },
                    priority: 1,
                    weather_dependency: 'low',
                    time_per_sqm: '0',
                    amount: '',
                    amount_unit: '',
                    source: 'blueprint',
                    master: null,
                    history: { rescheduled_at: null, cancelled_at: null }
                  },
                  badge: { type: 'planned' }
                }
              ],
              fertilizer: [],
              unscheduled: []
            }
          },
          {
            id: 2,
            name: 'Field B',
            crop_name: 'Carrot',
            area_sqm: 80,
            field_cultivation_id: 99,
            crop_id: 2,
            task_options: [],
            schedules: {
              general: [
                {
                  item_id: 2,
                  name: 'South task',
                  task_type: 'general',
                  category: 'general',
                  scheduled_date: '2026-06-12',
                  priority: 1,
                  source: 'blueprint',
                  weather_dependency: 'low',
                  time_per_sqm: '0',
                  amount: '',
                  amount_unit: '',
                  status: 'planned',
                  agricultural_task_id: 1,
                  field_cultivation_id: 99,
                  completed: false,
                  work_records: [],
                  details: {
                    stage: { name: 'Stage', order: 1 },
                    gdd: { trigger: '100', tolerance: '10' },
                    priority: 1,
                    weather_dependency: 'low',
                    time_per_sqm: '0',
                    amount: '',
                    amount_unit: '',
                    source: 'blueprint',
                    master: null,
                    history: { rescheduled_at: null, cancelled_at: null }
                  },
                  badge: { type: 'planned' }
                }
              ],
              fertilizer: [],
              unscheduled: []
            }
          }
        ]
      }
    }, { fromDate: '2026-01-01', fieldCultivationFilterId: 42 });
    filteredFixture.detectChanges();
    await filteredFixture.whenStable();

    expect(filteredFixture.nativeElement.textContent).toContain('North task');
    expect(filteredFixture.nativeElement.textContent).not.toContain('South task');
  });

  it('does not show redundant filter navigation when field_cultivation_id query param is set', async () => {
    TestBed.resetTestingModule();
    loadUseCase = { execute: vi.fn() };
    regenerateUseCase = { execute: vi.fn() };
    subscribeSyncUseCase = { execute: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    TestBed.overrideComponent(PlanTaskScheduleComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPlanTaskScheduleUseCase, useValue: loadUseCase },
          { provide: RegenerateTaskScheduleUseCase, useValue: regenerateUseCase },
          { provide: SubscribeTaskScheduleSyncUseCase, useValue: subscribeSyncUseCase },
          PlanTaskSchedulePresenter,
          { provide: ChangeDetectorRef, useValue: cdr },
          {
            provide: ActivatedRoute,
            useValue: {
              snapshot: {
                paramMap: { get: vi.fn(() => '7') },
                queryParamMap: {
                  get: vi.fn((key: string) => {
                    if (key === 'field_cultivation_id') return '42';
                    if (key === 'from_date') return '2026-01-01';
                    return null;
                  })
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
    const filteredPresenter = filteredFixture.debugElement.injector.get(PlanTaskSchedulePresenter);
    filteredFixture.detectChanges();
    setScheduleControl(filteredFixture.componentInstance, filteredPresenter, {
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
    }, { fromDate: '2026-01-01', fieldCultivationFilterId: 42 });
    filteredFixture.detectChanges();
    await filteredFixture.whenStable();

    expect(
      filteredFixture.nativeElement.querySelector('.plan-task-schedule__filter-nav')
    ).toBeNull();
  });
});

describe('PlanTaskScheduleComponent locale labels', () => {
  let fixture: ComponentFixture<PlanTaskScheduleComponent>;

  async function setupLocale(localeId: 'ja' | 'en' | 'in'): Promise<void> {
    loadUseCase = { execute: vi.fn() };
    regenerateUseCase = { execute: vi.fn() };
    subscribeSyncUseCase = { execute: vi.fn() };
    cdr = { markForCheck: vi.fn() };

    TestBed.resetTestingModule();
    TestBed.overrideComponent(PlanTaskScheduleComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPlanTaskScheduleUseCase, useValue: loadUseCase },
          { provide: RegenerateTaskScheduleUseCase, useValue: regenerateUseCase },
          { provide: SubscribeTaskScheduleSyncUseCase, useValue: subscribeSyncUseCase },
          PlanTaskSchedulePresenter,
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
