import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import { TaskScheduleVarianceViewComponent } from './task-schedule-variance-view.component';
import type { PlanTaskScheduleRowView } from './plan-task-schedule.view';

describe('TaskScheduleVarianceViewComponent', () => {
  let fixture: ComponentFixture<TaskScheduleVarianceViewComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TaskScheduleVarianceViewComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(TaskScheduleVarianceViewComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders summary stats and category table from API summary', async () => {
    fixture.componentInstance.stats = {
      completedCount: 3,
      averageDeltaDays: 2.5,
      unrecordedCount: 1
    };
    fixture.componentInstance.summary = {
      categories: [
        {
          category: 'general',
          average_delta_days: 3,
          item_count: 4,
          recorded_count: 2
        }
      ],
      top_variance_items: [
        {
          item_id: 11,
          field_cultivation_id: 10,
          category: 'general',
          name: 'Weeding',
          scheduled_date: '2026-06-01',
          actual_date: '2026-06-08',
          delta_days: 7,
          gdd_trigger: null,
          gdd_at_actual: null,
          gdd_delta: null
        }
      ]
    };
    fixture.detectChanges();
    await fixture.whenStable();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('Completed');
    expect(text).toContain('3');
    expect(text).toContain('Not recorded');
    expect(text).toContain('1');
    expect(text).toContain('General tasks');
    expect(text).toContain('Largest variance');
    expect(text).toContain('Weeding');
    expect(text).toContain('Δ +7 days');
  });

  it('renders unrecorded rows with schedule deep links', async () => {
    const row: PlanTaskScheduleRowView = {
      item: {
        item_id: 5,
        name: 'Mulching',
        scheduled_date: '2026-06-10',
        actualDate: null,
        deltaDays: null,
        gddTrigger: null,
        gddAtActual: null,
        gddDelta: null,
        status: 'planned',
        completed: false,
        details: {
          stageName: null,
          amount: null,
          amountUnit: null,
          masterDescription: null
        }
      },
      farmId: 0,
      farmName: '',
      planId: 7,
      planName: 'Plan',
      fieldId: 1,
      fieldName: 'Field A',
      fieldCultivationId: 42,
      cropName: 'Tomato',
      displayStatus: 'planned'
    };

    fixture.componentInstance.stats = {
      completedCount: 0,
      averageDeltaDays: null,
      unrecordedCount: 1
    };
    fixture.componentInstance.summary = {
      categories: [],
      top_variance_items: []
    };
    fixture.componentInstance.unrecordedRows = [row];
    fixture.detectChanges();
    await fixture.whenStable();

    const link = fixture.nativeElement.querySelector('.task-schedule-variance__list-link');
    expect(link?.textContent).toContain('Open in schedule');
    expect(link?.getAttribute('href')).toContain('/plans/7/task_schedule');
  });
});
