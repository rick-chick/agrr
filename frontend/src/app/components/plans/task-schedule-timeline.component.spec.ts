import { ComponentFixture, TestBed } from '@angular/core/testing';
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

function mockField(tasks: TaskScheduleItem[], fertilizer: TaskScheduleItem[] = []): FieldSchedule {
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
      unscheduled: []
    }
  };
}

describe('TaskScheduleTimelineComponent', () => {
  let fixture: ComponentFixture<TaskScheduleTimelineComponent>;
  let component: TaskScheduleTimelineComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TaskScheduleTimelineComponent, TranslateModule.forRoot()]
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
      'plans.task_schedules.field_number': '圃場 {{number}}'
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
});
