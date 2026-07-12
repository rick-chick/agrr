import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TaskScheduleItemDetailComponent } from './task-schedule-item-detail.component';
import type { PlanTaskScheduleItem } from '../../domain/work-schedule/plan-schedule-snapshot';

function mockTask(overrides: Partial<PlanTaskScheduleItem> = {}): PlanTaskScheduleItem {
  return {
    item_id: 1,
    name: 'Weeding',
    scheduled_date: '2026-06-17',
    status: 'planned',
    details: {
      stageName: 'Growth',
      gddTrigger: '120',
      gddTolerance: '10',
      amount: '10',
      amountUnit: 'g/m2',
      masterName: 'Weeding master',
      masterDescription: 'Remove weeds'
    },
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
