import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import type { PlanTaskScheduleMonthGroupView } from './plan-task-schedule.view';
import type { PlanTaskScheduleItem } from '../../domain/work-schedule/plan-schedule-snapshot';
import { TaskScheduleMonthListComponent } from './task-schedule-month-list.component';

function domainTask(
  overrides: Partial<PlanTaskScheduleItem> & Pick<PlanTaskScheduleItem, 'item_id' | 'name' | 'scheduled_date'>
): PlanTaskScheduleItem {
  return {
    item_id: overrides.item_id,
    name: overrides.name,
    scheduled_date: overrides.scheduled_date,
    status: overrides.status ?? 'planned',
    details: overrides.details ?? {
      stageName: 'Vegetative',
      gddTrigger: '150',
      gddTolerance: '5',
      amount: '20',
      amountUnit: 'kg',
      masterName: 'Weed master',
      masterDescription: 'Pull weeds carefully'
    }
  };
}

const monthGroups: PlanTaskScheduleMonthGroupView[] = [
  {
    monthKey: '2026-06',
    rows: [
      {
        item: domainTask({ item_id: 1, name: 'Weeding', scheduled_date: '2026-06-10' }),
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
        'plans.task_schedules.status.planned': 'Planned',
        'plans.task_schedules.detail.title': 'Task details',
        'plans.task_schedules.detail.stage': 'Stage',
        'plans.task_schedules.detail.not_applicable': 'N/A'
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

  it('shows task detail panel with stage name after row click', async () => {
    const rowButton = fixture.nativeElement.querySelector('.plan-task-schedule-month-list__row') as HTMLButtonElement;
    rowButton.click();
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.textContent).toContain('Vegetative');
    expect(fixture.nativeElement.textContent).toContain('Weed master');
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
