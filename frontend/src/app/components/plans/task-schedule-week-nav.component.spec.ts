import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import en from '../../../assets/i18n/en.json';
import type { TaskScheduleMinimap, WeekInfo } from '../../models/plans/task-schedule';
import { TaskScheduleWeekNavComponent } from './task-schedule-week-nav.component';

const weekInfo: WeekInfo = {
  start_date: '2026-06-01',
  end_date: '2026-06-07',
  label: '2026-06-01',
  days: []
};

const minimap: TaskScheduleMinimap = {
  start_date: '2026-05-25',
  end_date: '2026-06-14',
  weeks: [
    { start_date: '2026-05-25', label: '2026-05-25', task_count: 2, density: 'low', month_key: '2026-05' },
    { start_date: '2026-06-01', label: '2026-06-01', task_count: 5, density: 'medium', month_key: '2026-06' },
    { start_date: '2026-06-08', label: '2026-06-08', task_count: 1, density: 'low', month_key: '2026-06' }
  ]
};

describe('TaskScheduleWeekNavComponent', () => {
  let fixture: ComponentFixture<TaskScheduleWeekNavComponent>;
  let component: TaskScheduleWeekNavComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TaskScheduleWeekNavComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        ...(en as TranslationObject),
        'plans.task_schedules.view_mode_plan': 'List',
        'plans.task_schedules.view_mode_week': 'Week',
        'plans.task_schedules.nav_prev_week': 'Previous week',
        'plans.task_schedules.nav_next_week': 'Next week',
        'plans.task_schedules.nav_today': 'This week',
        'plans.task_schedules.week_label': '{{start}} – {{end}}'
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(TaskScheduleWeekNavComponent);
    component = fixture.componentInstance;
    component.viewMode = 'plan';
    component.week = weekInfo;
    component.minimap = minimap;
  });

  afterEach(() => {
    fixture.destroy();
    vi.restoreAllMocks();
  });

  function detect(): void {
    fixture.detectChanges();
  }

  it('renders plan and week mode toggle labels', () => {
    detect();
    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('List');
    expect(text).toContain('Week');
    expect(text).not.toContain('plans.task_schedules.view_mode_plan');
  });

  it('highlights plan mode as active by default', () => {
    detect();
    expect(
      fixture.nativeElement.querySelector('.task-schedule-week-nav__mode--plan')?.classList.contains(
        'task-schedule-week-nav__mode--active'
      )
    ).toBe(true);
  });

  it('highlights week mode when selected', () => {
    component.viewMode = 'week';
    detect();

    expect(
      fixture.nativeElement.querySelector('.task-schedule-week-nav__mode--week')?.classList.contains(
        'task-schedule-week-nav__mode--active'
      )
    ).toBe(true);
  });

  it('hides week navigation controls in plan mode', () => {
    detect();
    expect(fixture.nativeElement.querySelector('.task-schedule-week-nav__week-controls')).toBeNull();
  });

  it('shows week navigation controls in week mode', () => {
    component.viewMode = 'week';
    detect();

    const controls = fixture.nativeElement.querySelector('.task-schedule-week-nav__week-controls');
    expect(controls).toBeTruthy();
    expect(controls?.textContent).toContain('Previous week');
    expect(controls?.textContent).toContain('Next week');
    expect(controls?.textContent).toContain('This week');
    expect(controls?.textContent).toContain('June 1, 2026');
    expect(controls?.textContent).toContain('June 7, 2026');
  });

  it('emits viewModeChange when mode toggle is clicked', () => {
    detect();
    const spy = vi.fn();
    component.viewModeChange.subscribe(spy);

    (
      fixture.nativeElement.querySelector('.task-schedule-week-nav__mode--week') as HTMLButtonElement
    ).click();
    detect();

    expect(spy).toHaveBeenCalledWith('week');
  });

  it('emits weekChange with previous week start from minimap', () => {
    component.viewMode = 'week';
    detect();

    const spy = vi.fn();
    component.weekChange.subscribe(spy);

    (
      fixture.nativeElement.querySelector('.task-schedule-week-nav__prev') as HTMLButtonElement
    ).click();

    expect(spy).toHaveBeenCalledWith('2026-05-25');
  });

  it('emits weekChange with next week start from minimap', () => {
    component.viewMode = 'week';
    detect();

    const spy = vi.fn();
    component.weekChange.subscribe(spy);

    (
      fixture.nativeElement.querySelector('.task-schedule-week-nav__next') as HTMLButtonElement
    ).click();

    expect(spy).toHaveBeenCalledWith('2026-06-08');
  });

  it('emits weekToday when today button is clicked', () => {
    component.viewMode = 'week';
    detect();

    const spy = vi.fn();
    component.weekToday.subscribe(spy);

    (
      fixture.nativeElement.querySelector('.task-schedule-week-nav__today') as HTMLButtonElement
    ).click();

    expect(spy).toHaveBeenCalled();
  });

  it('emits weekChange when minimap chip is clicked', () => {
    component.viewMode = 'week';
    detect();

    const spy = vi.fn();
    component.weekChange.subscribe(spy);

    const chips = fixture.nativeElement.querySelectorAll('.task-schedule-week-nav__chip');
    expect(chips.length).toBe(3);
    (chips[2] as HTMLButtonElement).click();

    expect(spy).toHaveBeenCalledWith('2026-06-08');
  });
});
