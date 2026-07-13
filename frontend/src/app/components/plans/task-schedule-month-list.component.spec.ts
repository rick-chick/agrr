import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

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
    completed: overrides.completed ?? false,
    details: overrides.details ?? {
      stageName: 'Vegetative',
      amount: '20',
      amountUnit: 'kg',
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
        fieldId: 1,
        fieldCultivationId: 10,
        cropName: 'Tomato',
        displayStatus: 'planned'
      }
    ]
  }
];

describe('TaskScheduleMonthListComponent', () => {
  let fixture: ComponentFixture<TaskScheduleMonthListComponent>;
  let component: TaskScheduleMonthListComponent;

  beforeEach(async () => {
    HTMLDialogElement.prototype.showModal = vi.fn();
    HTMLDialogElement.prototype.close = vi.fn();

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
        'plans.task_schedules.status.completed': 'Completed',
        'plans.task_schedules.status.skipped': 'Skipped',
        'plans.task_schedules.detail.dialog_title': '{{task}} · {{crop}}',
        'plans.task_schedules.detail.stage': 'Stage',
        'plans.task_schedules.detail.not_applicable': 'N/A',
        'common.close': 'Close'
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
    expect(fixture.nativeElement.querySelectorAll('.plan-task-schedule-month-list__row')).toHaveLength(1);
    expect(fixture.nativeElement.textContent).toContain('Weeding');
    expect(fixture.nativeElement.textContent).toContain('Field A');
    expect(fixture.nativeElement.textContent).toContain('Tomato');
    expect(fixture.nativeElement.textContent).toContain('Planned');
  });

  it('prioritizes task name in main column with status badge', () => {
    const row = fixture.nativeElement.querySelector('.plan-task-schedule-month-list__row');
    const main = row?.querySelector('.plan-task-schedule-month-list__main');
    const name = main?.querySelector('.plan-task-schedule-month-list__name');
    const status = row?.querySelector('.plan-task-schedule-month-list__status--planned');

    expect(name?.textContent?.trim()).toBe('Weeding');
    expect(main?.querySelector('time.plan-task-schedule-month-list__date')).toBeTruthy();
    expect(status?.textContent?.trim()).toBe('Planned');
  });

  it('applies completed badge when work record linkage marks item completed', async () => {
    const completedFixture = TestBed.createComponent(TaskScheduleMonthListComponent);
    completedFixture.componentInstance.monthGroups = [
      {
        monthKey: '2026-06',
        rows: [
          {
            ...monthGroups[0].rows[0],
            item: domainTask({
              item_id: 2,
              name: 'Harvest',
              scheduled_date: '2026-06-11',
              status: 'planned',
              completed: true
            }),
            displayStatus: 'completed'
          }
        ]
      }
    ];
    completedFixture.detectChanges();
    await completedFixture.whenStable();

    const status = completedFixture.nativeElement.querySelector(
      '.plan-task-schedule-month-list__status--completed'
    );
    expect(status).toBeTruthy();
    expect(status?.textContent?.trim()).toBe('Completed');
    completedFixture.destroy();
  });

  it('applies skipped badge when item is skipped without work records', async () => {
    const skippedFixture = TestBed.createComponent(TaskScheduleMonthListComponent);
    skippedFixture.componentInstance.monthGroups = [
      {
        monthKey: '2026-06',
        rows: [
          {
            ...monthGroups[0].rows[0],
            item: domainTask({
              item_id: 3,
              name: 'Skipped task',
              scheduled_date: '2026-06-12',
              status: 'skipped',
              completed: false
            }),
            displayStatus: 'skipped'
          }
        ]
      }
    ];
    skippedFixture.detectChanges();
    await skippedFixture.whenStable();

    const status = skippedFixture.nativeElement.querySelector(
      '.plan-task-schedule-month-list__status--skipped'
    );
    expect(status).toBeTruthy();
    expect(status?.textContent?.trim()).toBe('Skipped');
    skippedFixture.destroy();
  });

  it('opens detail dialog with hero, task and crop in title, and field context', async () => {
    const rowButton = fixture.nativeElement.querySelector('.plan-task-schedule-month-list__row') as HTMLButtonElement;
    rowButton.click();
    fixture.detectChanges();
    await fixture.whenStable();

    const dialog = fixture.nativeElement.querySelector('dialog.task-schedule-detail-dialog');
    expect(dialog).toBeTruthy();
    expect(dialog?.querySelector('.task-schedule-detail-dialog__hero')).toBeTruthy();
    expect(dialog?.querySelector('.task-schedule-detail-dialog__title')?.textContent).toContain('Weeding');
    expect(dialog?.querySelector('.task-schedule-detail-dialog__title')?.textContent).toContain('Tomato');
    expect(dialog?.querySelector('.task-schedule-detail-dialog__field')?.textContent).toContain('Field A');
    expect(HTMLDialogElement.prototype.showModal).toHaveBeenCalled();
  });

  it('renders task detail inside dialog, not as inline panel below list', async () => {
    const rowButton = fixture.nativeElement.querySelector('.plan-task-schedule-month-list__row') as HTMLButtonElement;
    rowButton.click();
    fixture.detectChanges();
    await fixture.whenStable();

    const dialog = fixture.nativeElement.querySelector('dialog.form-dialog');
    expect(dialog?.querySelector('app-task-schedule-item-detail')).toBeTruthy();

    const monthSection = fixture.nativeElement.querySelector('.plan-task-schedule-month-list__month');
    expect(monthSection?.parentElement?.nextElementSibling?.tagName.toLowerCase()).toBe('dialog');
    expect(monthSection?.parentElement?.parentElement?.querySelector(':scope > app-task-schedule-item-detail')).toBeNull();
  });

  it('closes dialog when backdrop is clicked', async () => {
    const rowButton = fixture.nativeElement.querySelector('.plan-task-schedule-month-list__row') as HTMLButtonElement;
    rowButton.click();
    fixture.detectChanges();
    await fixture.whenStable();

    const dialog = fixture.nativeElement.querySelector(
      'dialog.task-schedule-detail-dialog'
    ) as HTMLDialogElement;
    dialog.dispatchEvent(new MouseEvent('click', { bubbles: false }));

    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
  });

  it('does not close dialog when dialog content is clicked', async () => {
    const rowButton = fixture.nativeElement.querySelector('.plan-task-schedule-month-list__row') as HTMLButtonElement;
    rowButton.click();
    fixture.detectChanges();
    await fixture.whenStable();

    const title = fixture.nativeElement.querySelector(
      '.task-schedule-detail-dialog__title'
    ) as HTMLElement;
    vi.mocked(HTMLDialogElement.prototype.close).mockClear();
    title.dispatchEvent(new MouseEvent('click', { bubbles: true }));

    expect(HTMLDialogElement.prototype.close).not.toHaveBeenCalled();
  });

  it('closes dialog when close button is clicked', async () => {
    const rowButton = fixture.nativeElement.querySelector('.plan-task-schedule-month-list__row') as HTMLButtonElement;
    rowButton.click();
    fixture.detectChanges();
    await fixture.whenStable();

    const closeButton = fixture.nativeElement.querySelector(
      'dialog.form-dialog .task-schedule-detail-dialog__actions .btn-secondary'
    ) as HTMLButtonElement;
    expect(closeButton.textContent).toContain('Close');

    closeButton.click();
    expect(HTMLDialogElement.prototype.close).toHaveBeenCalled();
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
