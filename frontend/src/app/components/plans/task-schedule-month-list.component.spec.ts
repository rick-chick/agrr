import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import en from '../../../assets/i18n/en.json';
import type { CrossFarmScheduleMonthGroup } from '../../domain/work-schedule/group-cross-farm-schedule-by-month';
import type { TaskScheduleItem } from '../../models/plans/task-schedule';
import { TaskScheduleMonthListComponent } from './task-schedule-month-list.component';

function task(
  overrides: Partial<TaskScheduleItem> & Pick<TaskScheduleItem, 'item_id' | 'name' | 'scheduled_date'>
): TaskScheduleItem {
  return {
    item_id: overrides.item_id,
    name: overrides.name,
    scheduled_date: overrides.scheduled_date,
    task_type: 'general',
    category: 'general',
    priority: 1,
    source: 'blueprint',
    weather_dependency: 'low',
    time_per_sqm: '0',
    amount: '',
    amount_unit: '',
    status: overrides.status ?? 'planned',
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
  };
}

const monthGroups: CrossFarmScheduleMonthGroup[] = [
  {
    monthKey: '2026-06',
    rows: [
      {
        item: task({ item_id: 1, name: 'Weeding', scheduled_date: '2026-06-10' }),
        farmId: 0,
        farmName: '',
        planId: 7,
        planName: 'Main Plan',
        fieldName: 'Field A',
        fieldCultivationId: 10,
        cropName: 'Tomato'
      }
    ]
  }
];

describe('TaskScheduleMonthListComponent', () => {
  let fixture: ComponentFixture<TaskScheduleMonthListComponent>;
  let component: TaskScheduleMonthListComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TaskScheduleMonthListComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        ...(en as TranslationObject),
        'plans.task_schedules.list_empty': 'No tasks match the current filters.',
        'plans.task_schedules.list_row_meta': '{{field}} · {{crop}}',
        'plans.task_schedules.status.planned': 'Planned'
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(TaskScheduleMonthListComponent);
    component = fixture.componentInstance;
    component.monthGroups = monthGroups;
    fixture.detectChanges();
    await fixture.whenStable();
  });

  it('renders month groups with task rows', () => {
    expect(fixture.nativeElement.querySelectorAll('.plan-task-schedule-month-list__item')).toHaveLength(1);
    expect(fixture.nativeElement.textContent).toContain('Weeding');
    expect(fixture.nativeElement.textContent).toContain('Field A');
    expect(fixture.nativeElement.textContent).toContain('Tomato');
    expect(fixture.nativeElement.textContent).toContain('Planned');
  });

  it('emits taskSelect when a row is clicked', () => {
    const handler = vi.fn();
    component.taskSelect.subscribe(handler);

    fixture.nativeElement.querySelector('.plan-task-schedule-month-list__row')?.click();

    expect(handler).toHaveBeenCalledWith(monthGroups[0]?.rows[0]?.item);
  });

  it('shows empty message when no month groups are provided', async () => {
    const emptyFixture = TestBed.createComponent(TaskScheduleMonthListComponent);
    emptyFixture.componentInstance.monthGroups = [];
    emptyFixture.detectChanges();
    await emptyFixture.whenStable();

    expect(emptyFixture.nativeElement.querySelector('.plan-task-schedule-month-list__empty')).toBeTruthy();
    expect(emptyFixture.nativeElement.textContent).toContain('No tasks match the current filters.');
    emptyFixture.destroy();
  });
});
