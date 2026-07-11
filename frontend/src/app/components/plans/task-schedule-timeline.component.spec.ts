import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TaskScheduleTimelineComponent } from './task-schedule-timeline.component';
import type { FieldSchedule, TaskScheduleItem } from '../../models/plans/task-schedule';

function mockTask(overrides: Partial<TaskScheduleItem> = {}): TaskScheduleItem {
  return {
    item_id: 1,
    name: 'Weeding',
    task_type: 'field_work',
    category: 'general',
    scheduled_date: '2026-06-17',
    stage_name: '',
    stage_order: 0,
    gdd_trigger: '',
    gdd_tolerance: '',
    priority: 1,
    source: 'agrr',
    weather_dependency: 'none',
    time_per_sqm: '',
    amount: '',
    amount_unit: '',
    status: 'planned',
    agricultural_task_id: 1,
    field_cultivation_id: 1,
    completed: false,
    work_records: [],
    details: {} as TaskScheduleItem['details'],
    badge: { type: 'default', priority_level: '', status: 'planned', category: 'general' },
    ...overrides
  };
}

function mockDetails(overrides: Partial<TaskScheduleItem['details']> = {}): TaskScheduleItem['details'] {
  return {
    stage: { name: 'Vegetative', order: 2 },
    gdd: { trigger: '120', tolerance: '10' },
    priority: 2,
    weather_dependency: 'low',
    time_per_sqm: '0.5',
    amount: '15',
    amount_unit: 'g/㎡',
    source: 'agrr',
    master: {
      name: 'Basal dressing',
      description: 'Apply before transplant',
      time_per_sqm: '0.5',
      weather_dependency: 'low',
      required_tools: ['Spreader'],
      skill_level: 'beginner',
      task_type: 'fertilizer'
    },
    history: { rescheduled_at: null, cancelled_at: null },
    ...overrides
  };
}

function mockField(
  tasks: TaskScheduleItem[],
  fertilizer: TaskScheduleItem[] = [],
  unscheduled: TaskScheduleItem[] = []
): FieldSchedule {
  return {
    id: 1,
    name: 'Field A',
    crop_name: 'Tomato',
    area_sqm: 100,
    field_cultivation_id: 1,
    crop_id: 1,
    task_options: [],
    schedules: {
      general: tasks,
      fertilizer,
      unscheduled
    }
  };
}

describe('TaskScheduleTimelineComponent', () => {
  let fixture: ComponentFixture<TaskScheduleTimelineComponent>;
  let component: TaskScheduleTimelineComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TaskScheduleTimelineComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation('ja', {
      'plans.task_schedules.general_label': '一般作業',
      'plans.task_schedules.fertilizer_label': '施肥',
      'plans.task_schedules.no_schedules': '作業予定がまだ生成されていません。',
      'plans.task_schedules.status.planned': '予定',
      'plans.task_schedules.status.skipped': 'スキップ',
      'plans.task_schedules.status.completed': '完了',
      'plans.task_schedules.field_section': '{{name}}（{{crop}}）',
      'plans.task_schedules.field_number': '圃場 {{number}}',
      'plans.task_schedules.cultivation_period': '栽培期間 {{start}} 〜 {{end}}',
      'plans.task_schedules.field_no_tasks': 'この列に予定された作業はありません',
      'plans.task_schedules.fertilizer_empty': '施肥予定はありません',
      'plans.task_schedules.unscheduled_title': '未確定の作業',
      'plans.task_schedules.detail.title': '作業詳細',
      'plans.task_schedules.detail.empty': 'タスクを選択すると詳細が表示されます',
      'plans.task_schedules.detail.scheduled_date': '予定日',
      'plans.task_schedules.detail.stage': 'ステージ',
      'plans.task_schedules.detail.amount': '施肥量',
      'plans.task_schedules.detail.master_name': '作業マスタ',
      'plans.task_schedules.detail.master_description': '作業説明',
      'plans.task_schedules.detail.not_applicable': '該当なし',
      'crops.show.gdd_trigger': 'GDDトリガー'
    });

    fixture = TestBed.createComponent(TaskScheduleTimelineComponent);
    component = fixture.componentInstance;
  });

  afterEach(() => {
    fixture.destroy();
  });

  it('renders translated status labels instead of raw status codes', async () => {
    component.fields = [
      mockField([
        mockTask({ item_id: 1, name: 'Task A', status: 'planned' }),
        mockTask({ item_id: 2, name: 'Task B', status: 'skipped' }),
        mockTask({ item_id: 3, name: 'Task C', status: 'completed' })
      ])
    ];
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('予定');
    expect(text).toContain('スキップ');
    expect(text).toContain('完了');
    expect(text).not.toContain('PLANNED');
    expect(text).not.toContain('planned');
    expect(text).not.toContain('skipped');
  });

  it('does not apply uppercase transform to status badge', () => {
    component.fields = [mockField([mockTask()])];
    fixture.detectChanges();

    const badge = fixture.nativeElement.querySelector('.badge');
    expect(badge).toBeTruthy();
    const styles = getComputedStyle(badge);
    expect(styles.textTransform).not.toBe('uppercase');
  });

  it('renders status badges on fertilizer tasks', async () => {
    component.fields = [
      mockField([], [mockTask({ item_id: 10, name: 'Basal', status: 'planned' })])
    ];
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Basal');
    expect(text).toContain('予定');
  });

  it('prefixes numeric field names in section heading', () => {
    component.fields = [
      {
        ...mockField([mockTask()]),
        name: '1',
        crop_name: 'かぼちゃ'
      }
    ];
    fixture.detectChanges();

    const heading = fixture.nativeElement.querySelector('.field-section h3');
    expect(heading?.textContent).toContain('圃場 1');
    expect(heading?.textContent).toContain('かぼちゃ');
  });

  it('displays scheduled_date per task using locale formatting', async () => {
    component.fields = [
      mockField([mockTask({ item_id: 1, name: 'Weeding', scheduled_date: '2026-06-25' })])
    ];
    fixture.detectChanges();
    await fixture.whenStable();

    const dateEl = fixture.nativeElement.querySelector('.item__date');
    expect(dateEl?.textContent).toContain('2026年6月25日');
  });

  it('includes cultivation period in field heading when dates are present', () => {
    component.fields = [
      {
        ...mockField([mockTask()]),
        name: 'Field A',
        crop_name: 'Tomato',
        cultivation_start_date: '2026-04-01',
        cultivation_end_date: '2026-10-31'
      }
    ];
    fixture.detectChanges();

    const heading = fixture.nativeElement.querySelector('.field-section h3');
    expect(heading?.textContent).toContain('栽培期間');
    expect(heading?.textContent).toContain('2026年4月1日');
    expect(heading?.textContent).toContain('2026年10月31日');
  });

  it('sorts tasks by scheduled_date ascending with nulls last', () => {
    component.fields = [
      mockField([
        mockTask({ item_id: 1, name: 'Later', scheduled_date: '2026-06-20' }),
        mockTask({ item_id: 2, name: 'Earlier', scheduled_date: '2026-06-10' }),
        mockTask({ item_id: 3, name: 'Unscheduled', scheduled_date: null })
      ])
    ];
    fixture.detectChanges();

    const names = Array.from(fixture.nativeElement.querySelectorAll('.item__name')).map(
      (el: Element) => el.textContent?.trim()
    );
    expect(names).toEqual(['Earlier', 'Later', 'Unscheduled']);
  });

  it('shows empty column message when a field section has no tasks', async () => {
    component.fields = [mockField([], [])];
    fixture.detectChanges();
    await fixture.whenStable();

    const emptyMessages = fixture.nativeElement.querySelectorAll('.column-empty');
    expect(emptyMessages.length).toBe(3);
    expect(emptyMessages[0]?.textContent).toContain('この列に予定された作業はありません');
  });

  it('shows fertilizer_empty when fertilizer column has no tasks', async () => {
    component.fields = [mockField([mockTask({ item_id: 1, name: 'Weeding' })], [])];
    fixture.detectChanges();
    await fixture.whenStable();

    const columns = fixture.nativeElement.querySelectorAll('.column');
    expect(columns.length).toBe(3);
    expect(columns[1]?.textContent).toContain('施肥予定はありません');
    expect(columns[1]?.textContent).not.toContain('この列に予定された作業はありません');
  });

  it('renders unscheduled section with tasks', async () => {
    component.fields = [
      mockField(
        [],
        [],
        [mockTask({ item_id: 20, name: 'Pending task', scheduled_date: null })]
      )
    ];
    fixture.detectChanges();
    await fixture.whenStable();

    const columns = fixture.nativeElement.querySelectorAll('.column');
    expect(columns.length).toBe(3);
    expect(columns[2]?.querySelector('h4')?.textContent).toContain('未確定の作業');
    expect(columns[2]?.textContent).toContain('Pending task');
  });

  it('shows detail panel empty state before a task is selected', () => {
    component.fields = [mockField([mockTask()])];
    fixture.detectChanges();

    const panel = fixture.nativeElement.querySelector('.task-detail-panel');
    expect(panel).toBeTruthy();
    expect(panel?.textContent).toContain('タスクを選択すると詳細が表示されます');
  });

  it('shows task details when a task row is clicked', async () => {
    component.fields = [
      mockField([
        mockTask({
          item_id: 5,
          name: 'Basal dressing',
          scheduled_date: '2026-06-17',
          details: mockDetails()
        })
      ])
    ];
    fixture.detectChanges();

    const row = fixture.nativeElement.querySelector('.item--selectable') as HTMLElement;
    row.click();
    fixture.detectChanges();
    await fixture.whenStable();

    const panel = fixture.nativeElement.querySelector('.task-detail-panel');
    expect(panel?.textContent).toContain('作業詳細');
    expect(panel?.textContent).toContain('2026年6月17日');
    expect(panel?.textContent).toContain('Vegetative');
    expect(panel?.textContent).toContain('120');
    expect(panel?.textContent).toContain('15');
    expect(panel?.textContent).toContain('Basal dressing');
    expect(panel?.textContent).toContain('Apply before transplant');
  });

  it('links field heading to planting plan when planId is provided', () => {
    component.fields = [mockField([mockTask()])];
    component.planId = 7;
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('.field-section__plan-link');
    expect(link).toBeTruthy();
    expect(link.getAttribute('href')).toContain('/plans/7');
  });

  it('renders plain heading without link when planId is not provided', () => {
    component.fields = [mockField([mockTask()])];
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.field-section__plan-link')).toBeNull();
    expect(fixture.nativeElement.querySelector('.field-section h3')?.textContent).toContain('Field A');
  });
});
