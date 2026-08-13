import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import en from '../../../assets/i18n/en.json';
import type { PlanTaskScheduleMonthGroupView } from './plan-task-schedule.view';
import type { PlanTaskScheduleItem } from '../../domain/work-schedule/plan-schedule-snapshot';
import { emptyPlanTaskScheduleItemVariance } from '../../domain/work-schedule/plan-schedule-snapshot';
import { TaskScheduleMonthListComponent } from './task-schedule-month-list.component';

function domainTask(
  overrides: Partial<PlanTaskScheduleItem> & Pick<PlanTaskScheduleItem, 'item_id' | 'name' | 'scheduled_date'>
): PlanTaskScheduleItem {
  return {
    status: overrides.status ?? 'planned',
    completed: overrides.completed ?? false,
    details: overrides.details ?? {
      stageName: 'Vegetative',
      amount: '20',
      amountUnit: 'kg',
      masterDescription: 'Pull weeds carefully'
    },
    ...emptyPlanTaskScheduleItemVariance,
    ...overrides
  };
}

const monthGroups: PlanTaskScheduleMonthGroupView[] = [
  {
    monthKey: '2026-06',
    averageDeltaDays: null,
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
      imports: [TaskScheduleMonthListComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        ...(en as TranslationObject),
        'plans.task_schedules.list_empty': 'No tasks match the current filters.',
        'plans.task_schedules.list_row_meta': '{{field}} · {{crop}}',
        'plans.task_schedules.unscheduled_title': 'Unconfirmed tasks',
        'plans.task_schedules.status.planned': 'Planned',
        'plans.task_schedules.status.completed': 'Completed',
        'plans.task_schedules.status.skipped': 'Skipped',
        'plans.task_schedules.detail.dialog_title': '{{task}} · {{crop}}',
        'plans.task_schedules.detail.stage': 'Stage',
        'plans.task_schedules.detail.not_applicable': 'N/A',
        'common.close': 'Close',
        'plans.task_schedules.variance.month_average': 'Monthly avg Δ {{delta}} days',
        'plans.task_schedules.variance.badge.late': '{{delta}} days late'
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
    expect(main?.querySelector('input.plan-task-schedule-month-list__date-input')).toBeTruthy();
    expect(status?.textContent?.trim()).toBe('Planned');
  });

  it('emits scheduledDateChange when inline date input changes', () => {
    const emitSpy = vi.fn();
    component.scheduledDateChange.subscribe(emitSpy);

    const dateInput = fixture.nativeElement.querySelector(
      'input.plan-task-schedule-month-list__date-input'
    ) as HTMLInputElement;
    dateInput.value = '2026-06-20';
    dateInput.dispatchEvent(new Event('change'));

    expect(emitSpy).toHaveBeenCalledWith({ itemId: 1, scheduledDate: '2026-06-20' });
  });

  it('applies completed badge when work record linkage marks item completed', async () => {
    const completedFixture = TestBed.createComponent(TaskScheduleMonthListComponent);
    completedFixture.componentInstance.monthGroups = [
      {
        monthKey: '2026-06',
        averageDeltaDays: null,
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
        averageDeltaDays: null,
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

  it('renders unscheduled section when unscheduled rows are provided', async () => {
    const unscheduledFixture = TestBed.createComponent(TaskScheduleMonthListComponent);
    unscheduledFixture.componentInstance.monthGroups = [];
    unscheduledFixture.componentInstance.unscheduledRows = [
      {
        item: domainTask({ item_id: 99, name: 'Pending prep', scheduled_date: null }),
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
    ];
    unscheduledFixture.detectChanges();
    await unscheduledFixture.whenStable();

    const section = unscheduledFixture.nativeElement.querySelector(
      '.plan-task-schedule-month-list__month--unscheduled'
    );
    expect(section).toBeTruthy();
    expect(section?.textContent).toContain('Unconfirmed tasks');
    expect(section?.textContent).toContain('Pending prep');
    expect(section?.querySelector('time.plan-task-schedule-month-list__date')).toBeFalsy();
    unscheduledFixture.destroy();
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

  it('renders variance badge for late recorded task', async () => {
    const lateFixture = TestBed.createComponent(TaskScheduleMonthListComponent);
    lateFixture.componentInstance.monthGroups = [
      {
        monthKey: '2026-06',
        averageDeltaDays: 3,
        rows: [
          {
            ...monthGroups[0].rows[0],
            item: domainTask({
              item_id: 4,
              name: 'Late task',
              scheduled_date: '2026-06-10',
              actualDate: '2026-06-13',
              deltaDays: 3
            })
          }
        ]
      }
    ];
    lateFixture.detectChanges();
    await lateFixture.whenStable();

    expect(
      lateFixture.nativeElement.querySelector('.plan-task-schedule-month-list__variance--late')
    ).toBeTruthy();
    expect(lateFixture.nativeElement.textContent).toContain('+3');
    expect(lateFixture.nativeElement.textContent).toContain('Monthly avg');
    lateFixture.destroy();
  });

  it('renders unrecorded variance badge when scheduled but no actual date', async () => {
    const unrecordedFixture = TestBed.createComponent(TaskScheduleMonthListComponent);
    unrecordedFixture.componentInstance.monthGroups = [
      {
        monthKey: '2026-06',
        averageDeltaDays: null,
        rows: [
          {
            ...monthGroups[0].rows[0],
            item: domainTask({
              item_id: 5,
              name: 'Pending',
              scheduled_date: '2026-06-10'
            })
          }
        ]
      }
    ];
    unrecordedFixture.detectChanges();
    await unrecordedFixture.whenStable();

    expect(
      unrecordedFixture.nativeElement.querySelector(
        '.plan-task-schedule-month-list__variance--unrecorded'
      )
    ).toBeTruthy();
    unrecordedFixture.destroy();
  });

  it('links variance badge to Learn variance section when planId is set', async () => {
    const linkFixture = TestBed.createComponent(TaskScheduleMonthListComponent);
    linkFixture.componentInstance.planId = 7;
    linkFixture.componentInstance.monthGroups = [
      {
        monthKey: '2026-06',
        averageDeltaDays: null,
        rows: [
          {
            ...monthGroups[0].rows[0],
            item: domainTask({
              item_id: 6,
              name: 'Late linked',
              scheduled_date: '2026-06-10',
              actualDate: '2026-06-13',
              deltaDays: 3
            })
          }
        ]
      }
    ];
    linkFixture.detectChanges();
    await linkFixture.whenStable();

    const link = linkFixture.nativeElement.querySelector(
      'a.plan-task-schedule-month-list__variance-link'
    ) as HTMLAnchorElement;
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/plans/7/learn');
    expect(link.getAttribute('href')).toContain('plan-learn-current-variance-title');
    linkFixture.destroy();
  });
});
