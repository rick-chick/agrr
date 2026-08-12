import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TaskScheduleItemDetailComponent } from './task-schedule-item-detail.component';
import type { PlanTaskScheduleItem } from '../../domain/work-schedule/plan-schedule-snapshot';
import { emptyPlanTaskScheduleItemVariance } from '../../domain/work-schedule/plan-schedule-snapshot';

function mockTask(overrides: Partial<PlanTaskScheduleItem> = {}): PlanTaskScheduleItem {
  return {
    item_id: 1,
    name: 'Weeding',
    scheduled_date: '2026-06-17',
    status: 'planned',
    completed: false,
    details: {
      stageName: 'Growth',
      amount: '10',
      amountUnit: 'g/m2',
      masterDescription: 'Remove weeds'
    },
    ...emptyPlanTaskScheduleItemVariance,
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
      'plans.task_schedules.detail.stage': 'ステージ',
      'plans.task_schedules.detail.amount': '施肥量',
      'plans.task_schedules.detail.master_description': '作業説明',
      'plans.task_schedules.detail.empty': 'タスクを選択すると詳細が表示されます',
      'plans.task_schedules.detail.not_applicable': '該当なし',
      'plans.task_schedules.detail.variance_heading': '予定と実績の比較',
      'plans.task_schedules.detail.scheduled_date': '予定日',
      'plans.task_schedules.detail.actual_date': '実施日',
      'plans.task_schedules.detail.delta_days': '日数差',
      'plans.task_schedules.detail.planned_gdd': '予定 GDD',
      'plans.task_schedules.detail.actual_gdd': '実施 GDD',
      'plans.task_schedules.detail.gdd_delta': 'GDD 差'
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

  it('shows stage, amount, and description for selected task', () => {
    component.task = mockTask();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelectorAll('.task-schedule-detail__facts')[0].querySelectorAll('.task-schedule-detail__fact')).toHaveLength(3);

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Growth');
    expect(text).toContain('10');
    expect(text).toContain('Remove weeds');
  });

  it('shows not applicable labels when detail values are missing', () => {
    component.task = mockTask({
      details: {
        stageName: 'Growth',
        amount: null,
        amountUnit: null,
        masterDescription: null
      }
    });
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('施肥量');
    expect(text).toContain('作業説明');
    expect(text).toContain('該当なし');
    expect(text).toContain('Growth');
  });

  it('shows plan vs actual comparison with date variance only when gdd is missing', () => {
    component.task = mockTask({
      actualDate: '2026-06-20',
      deltaDays: 3
    });
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('予定と実績の比較');
    expect(text).toContain('予定日');
    expect(text).toContain('実施日');
    expect(text).toContain('+3');
    expect(text).not.toContain('予定 GDD');
  });

  it('shows gdd comparison when gdd_at_actual is present', () => {
    component.task = mockTask({
      actualDate: '2026-06-20',
      deltaDays: 3,
      gddTrigger: 100,
      gddAtActual: 110,
      gddDelta: 10
    });
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('予定 GDD');
    expect(text).toContain('実施 GDD');
    expect(text).toContain('100');
    expect(text).toContain('110');
    expect(text).toContain('+10');
  });
});
