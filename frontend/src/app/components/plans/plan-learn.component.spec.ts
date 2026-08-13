import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BehaviorSubject } from 'rxjs';

import en from '../../../assets/i18n/en.json';
import { LoadBlueprintTimingAdjustmentProposalsUseCase } from '../../usecase/plans/load-blueprint-timing-adjustment-proposals.usecase';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { LoadPlanVsActualSummaryUseCase } from '../../usecase/plans/load-plan-vs-actual-summary.usecase';
import { PlanLearnPresenter } from '../../usecase/plans/plan-learn.providers';
import { PlanLearnComponent } from './plan-learn.component';
import type { TaskScheduleResponse } from '../../models/plans/task-schedule';
import {
  markStageGddProposalAppliedPending,
  storeLearnPostMasterPayload
} from '../../domain/plans/learn-proposal-application-progress';

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

function createRouteMock(planId: string, queryParams: Record<string, string> = {}) {
  const paramMapSubject = new BehaviorSubject({
    get: (key: string) => (key === 'id' ? planId : null)
  });
  const queryParamMapSubject = new BehaviorSubject({
    get: (key: string) => queryParams[key] ?? null
  });
  return {
    snapshot: {
      get paramMap() {
        return paramMapSubject.value;
      },
      get queryParamMap() {
        return queryParamMapSubject.value;
      }
    },
    paramMap: paramMapSubject.asObservable(),
    queryParamMap: queryParamMapSubject.asObservable()
  };
}

describe('PlanLearnComponent', () => {
  let fixture: ComponentFixture<PlanLearnComponent>;
  let scheduleUseCase: { execute: ReturnType<typeof vi.fn> };
  let varianceUseCase: { execute: ReturnType<typeof vi.fn> };
  let blueprintTimingUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: PlanLearnPresenter;

  beforeEach(async () => {
    sessionStorage.clear();
    scheduleUseCase = { execute: vi.fn() };
    varianceUseCase = { execute: vi.fn() };
    blueprintTimingUseCase = { execute: vi.fn() };

    TestBed.overrideComponent(PlanLearnComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPlanTaskScheduleUseCase, useValue: scheduleUseCase },
          { provide: LoadPlanVsActualSummaryUseCase, useValue: varianceUseCase },
          {
            provide: LoadBlueprintTimingAdjustmentProposalsUseCase,
            useValue: blueprintTimingUseCase
          },
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

  it('renders proposal cards when action_required_items are present', async () => {
    fixture.detectChanges();
    presenter.present({ schedule: loadedSchedule, loadGeneration: 0 });
    presenter.presentVarianceSummary({
      summary: {
        plan_id: 7,
        unrecorded_count: 0,
        categories: [],
        top_variance_items: [],
        action_required_items: [
          {
            item_id: 11,
            field_cultivation_id: 100,
            category: 'general',
            name: 'Weed control',
            scheduled_date: '2026-06-01',
            actual_date: '2026-06-08',
            delta_days: 7,
            gdd_trigger: 100,
            gdd_at_actual: 110,
            gdd_delta: 10,
            exceedance_kind: 'days'
          }
        ]
      },
      loadGeneration: 1
    });
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('app-variance-action-proposal-cards')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Schedule variance needs your review');
    expect(fixture.nativeElement.textContent).toContain('Weed control');
  });
});

describe('PlanLearnComponent post_master follow-up', () => {
  let fixture: ComponentFixture<PlanLearnComponent>;
  let scheduleUseCase: { execute: ReturnType<typeof vi.fn> };
  let varianceUseCase: { execute: ReturnType<typeof vi.fn> };
  let blueprintTimingUseCase: { execute: ReturnType<typeof vi.fn> };
  let presenter: PlanLearnPresenter;

  beforeEach(async () => {
    sessionStorage.clear();
    scheduleUseCase = { execute: vi.fn() };
    varianceUseCase = { execute: vi.fn() };
    blueprintTimingUseCase = { execute: vi.fn() };

    TestBed.overrideComponent(PlanLearnComponent, {
      set: {
        styleUrls: [],
        providers: [
          { provide: LoadPlanTaskScheduleUseCase, useValue: scheduleUseCase },
          { provide: LoadPlanVsActualSummaryUseCase, useValue: varianceUseCase },
          {
            provide: LoadBlueprintTimingAdjustmentProposalsUseCase,
            useValue: blueprintTimingUseCase
          },
          PlanLearnPresenter
        ]
      }
    });

    await TestBed.configureTestingModule({
      imports: [PlanLearnComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([{ path: 'plans/:id/learn', component: PlanLearnComponent }]),
        { provide: ActivatedRoute, useValue: createRouteMock('7', { followUp: 'post_master' }) }
      ]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(PlanLearnComponent);
    presenter = fixture.debugElement.injector.get(PlanLearnPresenter);
  });

  it('renders application progress and post_master confirmation when followUp is set', async () => {
    storeLearnPostMasterPayload(7, {
      kind: 'stage_gdd',
      cropId: 1,
      cropName: 'Tomato',
      stageId: 2,
      stageName: 'Vegetative',
      appliedRequiredGdd: 150
    });
    markStageGddProposalAppliedPending(7, { cropId: 1, stageId: 2 });

    fixture.detectChanges();
    presenter.present({ schedule: loadedSchedule, loadGeneration: 0 });
    presenter.presentVarianceSummary({
      summary: {
        plan_id: 7,
        unrecorded_count: 0,
        categories: [],
        top_variance_items: [],
        stage_gdd_calibration_proposals: [
          {
            crop_id: 1,
            crop_name: 'Tomato',
            stage_order: 1,
            stage_name: 'Vegetative',
            average_gdd_delta: 10,
            recorded_item_count: 2
          }
        ]
      },
      loadGeneration: 1
    });
    presenter.presentStageGddProposals({
      proposals: [
        {
          cropId: 1,
          cropName: 'Tomato',
          stageId: 2,
          stageOrder: 1,
          stageName: 'Vegetative',
          averageGddDelta: 10,
          recordedItemCount: 2,
          currentRequiredGdd: 100,
          proposedRequiredGdd: 150
        }
      ],
      loadGeneration: 1
    });
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fixture.nativeElement.querySelector('app-plan-learn-application-progress-view')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Proposal application progress');
    expect(fixture.nativeElement.textContent).toContain('Applied — pending confirmation');
    expect(fixture.nativeElement.querySelector('app-plan-learn-post-master-confirmation')).toBeTruthy();
    expect(fixture.nativeElement.textContent).toContain('Master update applied');
    expect(fixture.nativeElement.textContent).toContain('Verify placement on workbench');
  });
});
