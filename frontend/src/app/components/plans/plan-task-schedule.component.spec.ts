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
import { UndoToastService } from '../../services/undo-toast.service';

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
    task_schedule_sync_error: null
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
  minimap: {}
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

  beforeEach(async () => {
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
              snapshot: { paramMap: { get: vi.fn(() => '7') } }
            }
          }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanTaskScheduleComponent, TranslateModule.forRoot()],
      providers: [provideRouter([]), { provide: UndoToastService, useValue: { show: vi.fn(), hide: vi.fn() } }]
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

  it('shows link back to work hub', async () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    const back = fixture.nativeElement.querySelector('.plan-work-header__back');
    expect(back?.textContent).toContain('Back to work log');
    expect(fixture.nativeElement.querySelector('.plan-work__back-nav')).toBeNull();
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
  });

  it('renders page title in header before work navigation tabs', async () => {
    fixture.detectChanges();
    component.control = loadedState;
    fixture.detectChanges();
    await fixture.whenStable();

    const heading = fixture.nativeElement.querySelector('.page-header .page-title');
    const nav = fixture.nativeElement.querySelector('.plan-work-nav');
    expect(heading).toBeTruthy();
    expect(nav).toBeTruthy();
    expect(heading!.compareDocumentPosition(nav!) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
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
    expect(loadUseCase.execute).toHaveBeenCalledWith({ planId: 7 });
  });

  it('calls regenerate use case from sync banner retry', () => {
    fixture.detectChanges();
    component.control = {
      ...loadedState,
      schedule: {
        ...loadedSchedule,
        plan: {
          ...loadedSchedule.plan,
          task_schedule_sync_state: 'failed',
          task_schedule_sync_error: 'plans.task_schedules.sync_errors.agrr_unavailable'
        }
      }
    };
    fixture.detectChanges();

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
              snapshot: { paramMap: { get: vi.fn(() => '7') } }
            }
          }
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanTaskScheduleComponent, TranslateModule.forRoot()],
      providers: [provideRouter([]), { provide: UndoToastService, useValue: { show: vi.fn(), hide: vi.fn() } }]
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
    expect(text).toContain('計画詳細を見る');
    expect(text).toContain('Main Planの作業予定');
    expect(text).toContain('作業予定がまだ生成されていません。');
    expect(text).not.toContain('plans.task_schedules.');
  });

  it('renders English labels instead of raw i18n keys', async () => {
    await setupLocale('en');

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('View plan details');
    expect(text).toContain('Task schedule for Main Plan');
    expect(text).toContain('No task schedule has been generated yet.');
    expect(text).not.toContain('plans.task_schedules.');
  });

  it('renders Hindi labels instead of raw i18n keys', async () => {
    await setupLocale('in');

    const navLinks = fixture.nativeElement.querySelectorAll('.plan-work-nav__link');
    expect(navLinks.length).toBe(3);
    expect(navLinks[0].textContent?.trim()).toBe('आज का कार्य');
    expect(navLinks[1].textContent?.trim()).toBe('पूर्ण अनुसूची');
    expect(navLinks[2].textContent?.trim()).toBe('कार्य इतिहास');

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('योजना विवरण देखें');
    expect(text).toContain('Main Plan की कार्य अनुसूची');
    expect(text).toContain('अभी तक कोई कार्य अनुसूची नहीं बनाई गई है।');
    expect(text).not.toContain('plans.task_schedules.');
  });
});
