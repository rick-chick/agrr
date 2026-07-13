import { ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter, Router } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import en from '../../../assets/i18n/en.json';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { RegenerateTaskScheduleUseCase } from '../../usecase/plans/regenerate-task-schedule.usecase';
import { SubscribeTaskScheduleSyncUseCase } from '../../usecase/plans/subscribe-task-schedule-sync.usecase';
import { PlanTaskSchedulePresenter } from '../../usecase/plans/plan-task-schedule.providers';
import { PlanTaskScheduleComponent } from './plan-task-schedule.component';
import type { PlanTaskScheduleViewState } from './plan-task-schedule.view';
import type { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { localTodayIso } from '../../core/local-today';

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
  fieldFilterId: null,
  monthGroups: [],
  fieldFilterOptions: [],
  cropIdsForBanner: [],
  cropNamesForBanner: {},
  filteredFieldCount: 0,
  filteredTaskCount: 0,
  regenerateRequiresConfirm: false
};

function sampleGeneralTask(
  overrides: {
    item_id?: number;
    name?: string;
    scheduled_date?: string;
    field_cultivation_id?: number;
  } = {}
) {
  return {
    item_id: overrides.item_id ?? 1,
    name: overrides.name ?? 'Weeding',
    task_type: 'general' as const,
    category: 'general',
    scheduled_date: overrides.scheduled_date ?? localTodayIso(),
    priority: 1,
    source: 'blueprint',
    weather_dependency: 'low',
    time_per_sqm: '0',
    amount: '',
    amount_unit: '',
    status: 'planned' as const,
    agricultural_task_id: 1,
    field_cultivation_id: overrides.field_cultivation_id ?? 10,
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
    badge: { type: 'planned' as const }
  };
}

function setScheduleControl(
  component: PlanTaskScheduleComponent,
  presenter: PlanTaskSchedulePresenter,
  control: PlanTaskScheduleViewState,
  filters?: { fromDate?: string; fieldFilterId?: number | null; fieldCultivationFilterId?: number | null }
): void {
  component.control = control;
  if (control.schedule) {
    presenter.applyClientFilters(
      filters?.fromDate ?? control.fromDate,
      filters?.fieldFilterId ?? control.fieldFilterId,
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
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();

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
      fieldFilterId: null,
      fieldCultivationFilterId: null,
      monthGroups: [],
      fieldFilterOptions: [],
      cropIdsForBanner: [],
      cropNamesForBanner: {},
      filteredFieldCount: 0,
      filteredTaskCount: 0,
      regenerateRequiresConfirm: false
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

  it('renders schedule with month list and metadata footer', async () => {
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
              general: [sampleGeneralTask({ scheduled_date: today })],
              fertilizer: [],
              unscheduled: []
            }
          }
        ]
      }
    }, { fromDate: today });
    fixture.detectChanges();
    await fixture.whenStable();

    const footer = fixture.nativeElement.querySelector('.plan-task-schedule__footer');
    expect(footer).toBeTruthy();
    expect(footer?.querySelector('.plan-task-schedule__generated-at')?.textContent).toContain('Generated');
    expect(footer?.querySelector('.plan-task-schedule__summary')?.textContent).toContain('field');
    expect(footer?.querySelector('.plan-task-schedule__regenerate-link')?.textContent).toContain(
      'Regenerate task schedules'
    );
    expect(fixture.nativeElement.querySelector('app-task-schedule-month-list')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Weeding');
  });

  it('defaults fromDate filter to local today when query param is absent', async () => {
    fixture.detectChanges();
    expect(component.fromDate).toBe(localTodayIso());
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
                sampleGeneralTask({ item_id: 1, name: 'Past task', scheduled_date: '2026-06-01' }),
                sampleGeneralTask({ item_id: 2, name: 'Later task', scheduled_date: '2026-06-15' })
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
    expect(component.control.loading).toBe(true);
    expect(component.control.error).toBeNull();
  });

  it('registers view with presenter on init', () => {
    const setViewSpy = vi.spyOn(presenter, 'setView');

    component.ngOnInit();

    expect(setViewSpy).toHaveBeenCalledWith(component);
  });

  it('shows ready regenerate link in footer when sync is ready and schedule has fields', async () => {
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

    const footer = fixture.nativeElement.querySelector('.plan-task-schedule__footer');
    const link = footer?.querySelector('.plan-task-schedule__regenerate-link');
    expect(link?.textContent).toContain('Regenerate task schedules');
  });

  it('opens regenerate confirm dialog when existing tasks would be replaced', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

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
              general: [sampleGeneralTask()],
              fertilizer: [],
              unscheduled: []
            }
          }
        ]
      }
    });
    fixture.detectChanges();
    await fixture.whenStable();

    const link = fixture.nativeElement.querySelector('.plan-task-schedule__regenerate-link');
    link.click();

    expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
    expect(fixture.nativeElement.querySelector('.plan-task-schedule__regenerate-confirm')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain(
      'Regenerating will replace the current task schedule. Continue?'
    );
  });

  it('closes regenerate confirm on cancel and confirms before regenerating', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

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
              general: [sampleGeneralTask()],
              fertilizer: [],
              unscheduled: []
            }
          }
        ]
      }
    });
    fixture.detectChanges();
    await fixture.whenStable();

    const link = fixture.nativeElement.querySelector('.plan-task-schedule__regenerate-link');
    link.click();

    fixture.nativeElement
      .querySelector('.plan-task-schedule__regenerate-confirm .btn-secondary')
      ?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();

    vi.mocked(HTMLDialogElement.prototype.close).mockClear();
    link.click();
    const dialog = fixture.nativeElement.querySelector(
      '.plan-task-schedule__regenerate-confirm'
    ) as HTMLDialogElement;
    dialog.dispatchEvent(new MouseEvent('click', { bubbles: false }));
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();

    vi.mocked(HTMLDialogElement.prototype.close).mockClear();
    link.click();
    fixture.nativeElement
      .querySelector('.plan-task-schedule__regenerate-confirm .btn-primary')
      ?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
  });

  it('regenerates without confirm when schedule has no tasks', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

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
            schedules: { general: [], fertilizer: [], unscheduled: [] }
          }
        ]
      }
    });
    fixture.detectChanges();
    await fixture.whenStable();

    const link = fixture.nativeElement.querySelector('.plan-task-schedule__regenerate-link');
    link.click();

    expect(HTMLDialogElement.prototype.showModal).not.toHaveBeenCalled();
  });

  it('shows regenerate error in footer when sync is ready', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = {
      ...loadedState,
      regenerateError: 'plans.task_schedules.sync_errors.generic',
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

    const error = fixture.nativeElement.querySelector('.plan-task-schedule__footer .plan-task-schedule__regenerate-error');
    expect(error).toBeTruthy();
    expect(error?.getAttribute('role')).toBe('alert');
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
