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

  it('shows regenerate CTA in empty state when sync never generated', async () => {
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
          task_schedule_sync_error: null
        }
      }
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const regenerateBtn = fixture.nativeElement.querySelector('.plan-work__empty-cta');
    expect(regenerateBtn?.textContent).toContain('Regenerate task schedules');
    expect(fixture.nativeElement.querySelector('app-task-schedule-sync-banner')).toBeNull();
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
