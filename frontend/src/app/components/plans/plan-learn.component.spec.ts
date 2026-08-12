import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BehaviorSubject } from 'rxjs';

import en from '../../../assets/i18n/en.json';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { LoadPlanVsActualSummaryUseCase } from '../../usecase/plans/load-plan-vs-actual-summary.usecase';
import { PlanLearnPresenter } from '../../usecase/plans/plan-learn.providers';
import { PlanLearnComponent } from './plan-learn.component';
import type { TaskScheduleResponse } from '../../models/plans/task-schedule';

const loadedSchedule: TaskScheduleResponse = {
  plan: {
    id: 7,
    name: 'Main Plan',
    status: 'completed',
    planning_start_date: '2026-01-01',
    planning_end_date: '2026-12-31',
    timeline_generated_at: '2026-06-01T00:00:00Z',
    timeline_generated_at_display: '2026-06-01',
    task_schedule_sync_state: 'ready',
    task_schedule_sync_error: null,
    task_schedule_sync_error_crop_id: null
  },
  week: {
    start_date: '2026-06-01',
    end_date: '2026-06-07',
    label: '2026-06-01',
    days: []
  },
  milestones: [],
  fields: [],
  labels: {},
  minimap: {
    start_date: '2026-05-25',
    end_date: '2026-06-14',
    weeks: [
      { start_date: '2026-06-01', label: '2026-06-01', task_count: 5, density: 'medium', month_key: '2026-06' }
    ]
  }
};

function createRouteMock(planId: string) {
  const paramMapSubject = new BehaviorSubject({
    get: (key: string) => (key === 'id' ? planId : null)
  });
  return {
    snapshot: {
      get paramMap() {
        return paramMapSubject.value;
      }
    },
    paramMap: paramMapSubject.asObservable()
  };
}

describe('PlanLearnComponent', () => {
  let fixture: ComponentFixture<PlanLearnComponent>;
  let scheduleUseCase: { execute: ReturnType<typeof vi.fn> };
  let varianceUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: PlanLearnPresenter;

  beforeEach(async () => {
    scheduleUseCase = { execute: vi.fn() };
    varianceUseCase = { execute: vi.fn() };

    TestBed.overrideComponent(PlanLearnComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPlanTaskScheduleUseCase, useValue: scheduleUseCase },
          { provide: LoadPlanVsActualSummaryUseCase, useValue: varianceUseCase },
          PlanLearnPresenter
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanLearnComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([{ path: 'plans/:id/learn', component: PlanLearnComponent }]),
        { provide: ActivatedRoute, useValue: createRouteMock('7') }
      ]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(PlanLearnComponent);
    presenter = fixture.debugElement.injector.get(PlanLearnPresenter);
  });

  it('loads schedule and variance summary on init', () => {
    fixture.detectChanges();

    expect(scheduleUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 7 })
    );
    expect(varianceUseCase.execute).toHaveBeenCalledWith(
      expect.objectContaining({ planId: 7 })
    );
  });

  it('renders variance view when summary is loaded', async () => {
    fixture.detectChanges();
    presenter.present({ schedule: loadedSchedule, loadGeneration: 0 });
    presenter.presentVarianceSummary({
      summary: {
        plan_id: 7,
        unrecorded_count: 1,
        categories: [
          {
            category: 'general',
            average_delta_days: 2,
            item_count: 3,
            recorded_count: 2
          }
        ],
        top_variance_items: []
      },
      loadGeneration: 1
    });
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('app-task-schedule-variance-view')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Plan variance summary');
    expect(fixture.nativeElement.textContent).toContain('General tasks');
  });
});
