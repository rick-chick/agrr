import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TaskScheduleItemDetailComponent } from './task-schedule-item-detail.component';
import type { TaskScheduleItem } from '../../models/plans/task-schedule';

function mockTask(overrides: Partial<TaskScheduleItem> = {}): TaskScheduleItem {
  return {
    item_id: 1,
    name: 'Weeding',
    task_type: 'field_work',
    category: 'general',
    scheduled_date: '2026-06-17',
    stage_name: 'Growth',
    stage_order: 2,
    gdd_trigger: '120',
    gdd_tolerance: '10',
    priority: 1,
    source: 'agrr',
    weather_dependency: 'none',
    time_per_sqm: '',
    amount: '10',
    amount_unit: 'g/m2',
    status: 'planned',
    agricultural_task_id: 1,
    field_cultivation_id: 1,
    completed: false,
    work_records: [],
    details: {
      stage: { name: 'Growth', order: 2 },
      gdd: { trigger: '120', tolerance: '10' },
      priority: 1,
      weather_dependency: 'none',
      time_per_sqm: '',
      amount: '10',
      amount_unit: 'g/m2',
      source: 'agrr',
      master: {
        name: 'Weeding master',
        description: 'Remove weeds',
        time_per_sqm: '',
        weather_dependency: 'none',
        required_tools: [],
        skill_level: 'beginner',
        task_type: 'field_work'
      },
      history: { rescheduled_at: null, cancelled_at: null }
    },
    badge: { type: 'default', priority_level: '', status: 'planned', category: 'general' },
    ...overrides
  };
}

describe('TaskScheduleItemDetailComponent', () => {
  let fixture: ComponentFixture<TaskScheduleItemDetailComponent>;
  let component: TaskScheduleItemDetailComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TaskScheduleItemDetailComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('ja');
    translate.use('ja');
    translate.setTranslation('ja', {
      'plans.task_schedules.detail.title': '作業詳細',
      'plans.task_schedules.detail.scheduled_date': '予定日',
      'plans.task_schedules.detail.stage': 'ステージ',
      'plans.task_schedules.detail.amount': '施肥量',
      'plans.task_schedules.detail.master_name': '作業マスタ',
      'plans.task_schedules.detail.master_description': '作業説明',
      'plans.task_schedules.detail.empty': 'タスクを選択すると詳細が表示されます',
      'plans.task_schedules.detail.not_applicable': '該当なし',
      'crops.show.gdd_trigger': 'GDDトリガー'
    });

    fixture = TestBed.createComponent(TaskScheduleItemDetailComponent);
    component = fixture.componentInstance;
  });

  afterEach(() => {
    fixture.destroy();
  });

  it('shows empty message when no task selected', () => {
    component.task = null;
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('タスクを選択すると詳細が表示されます');
  });

  it('shows scheduled date, stage, GDD, and master fields for selected task', () => {
    component.task = mockTask();
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('2026年6月17日');
    expect(text).toContain('Growth');
    expect(text).toContain('120');
    expect(text).toContain('Weeding master');
    expect(text).toContain('Remove weeds');
  });
});
