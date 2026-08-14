import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { of } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PLAN_GATEWAY } from '../../usecase/plans/plan-gateway';
import { PlanTaskScheduleOrchestrationBannerComponent } from './plan-task-schedule-orchestration-banner.component';

const gatewayMock = {
  getPlanVsActualSummary: vi.fn().mockReturnValue(
    of({
      plan_id: 4,
      action_required_items: [
        {
          item_id: 1,
          field_cultivation_id: 1,
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
      ],
      unrecorded_count: 0,
      categories: [],
      top_variance_items: [],
      stage_gdd_calibration_proposals: [],
      blueprint_timing_adjustment_proposals: []
    })
  ),
  getVarianceLearning: vi.fn().mockReturnValue(of(null))
};

describe('PlanTaskScheduleOrchestrationBannerComponent', () => {
  let fixture: ComponentFixture<PlanTaskScheduleOrchestrationBannerComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanTaskScheduleOrchestrationBannerComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    })
      .overrideComponent(PlanTaskScheduleOrchestrationBannerComponent, {
        set: {
          providers: [{ provide: PLAN_GATEWAY, useValue: gatewayMock }]
        }
      })
      .compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.task_schedules.orchestration.regenerate.message': 'Regenerate recommended',
        'plans.task_schedules.orchestration.regenerate.hint': 'Use sync banner',
        'plans.task_schedules.orchestration.sync_verify.message': 'Verify sync',
        'plans.task_schedules.orchestration.sync_verify.hint': 'Check sync status',
        'plans.task_schedules.orchestration.work_retry': 'Open work screen',
        'plans.task_schedules.orchestration.return_to_learn': 'Return to learning screen',
        'plans.task_schedules.orchestration.loop_progress_title': 'Learning loop progress',
        'plans.learn.loop.phase.observe': 'Observe',
        'plans.learn.loop.phase.apply': 'Apply',
        'plans.learn.loop.phase.reorganize': 'Reorganize',
        'plans.learn.loop.phase.handoff': 'Handoff',
        'plans.learn.loop.phase.complete': 'Complete'
      },
      true
    );

    fixture = TestBed.createComponent(PlanTaskScheduleOrchestrationBannerComponent);
    fixture.componentInstance.planId = 4;
  });

  it('shows work retry link for sync_verify when sync failed', () => {
    fixture.componentInstance.mode = 'sync_verify';
    fixture.componentInstance.syncState = 'failed';
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.learn-orchestration-banner__work-link');
    expect(link).not.toBeNull();
    expect(link.getAttribute('href')).toBe('/plans/4/work');
    expect(link.textContent).toContain('Open work screen');
  });

  it('does not show work retry link when sync is ready', () => {
    fixture.componentInstance.mode = 'sync_verify';
    fixture.componentInstance.syncState = 'ready';
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('a.learn-orchestration-banner__work-link')).toBeNull();
  });

  it('shows return-to-learn link during orchestration even before completion', async () => {
    fixture.componentInstance.mode = 'regenerate';
    fixture.componentInstance.syncState = 'generating';
    fixture.componentInstance.orchestrationComplete = false;
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.learn-orchestration-banner__learn-link');
    expect(link).not.toBeNull();
    expect(link.getAttribute('href')).toBe('/plans/4/learn');
    expect(link.textContent).toContain('Return to learning screen');
  });

  it('renders learn loop progress phases in orchestration banner', async () => {
    fixture.componentInstance.mode = 'regenerate';
    fixture.componentInstance.syncState = 'ready';
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Learning loop progress');
    const currentPhase = fixture.nativeElement.querySelector(
      '.learn-orchestration-banner__loop-phase--current .learn-orchestration-banner__loop-phase-label'
    );
    expect(currentPhase?.textContent?.trim()).toBe('Observe');
  });
});
