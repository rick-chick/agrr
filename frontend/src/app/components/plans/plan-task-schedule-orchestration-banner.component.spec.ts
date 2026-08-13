import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanTaskScheduleOrchestrationBannerComponent } from './plan-task-schedule-orchestration-banner.component';
import {
  isLearnOrchestrationStepComplete,
  readLearnOrchestrationReturnToLearn
} from '../../domain/plans/learn-master-update-orchestration';

describe('PlanTaskScheduleOrchestrationBannerComponent', () => {
  let fixture: ComponentFixture<PlanTaskScheduleOrchestrationBannerComponent>;

  beforeEach(async () => {
    sessionStorage.clear();

    await TestBed.configureTestingModule({
      imports: [PlanTaskScheduleOrchestrationBannerComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

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
        'plans.task_schedules.orchestration.return_to_learn': 'Return to learning screen'
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

  it('shows return to learn link when orchestration is complete and return context is set', () => {
    fixture.componentInstance.mode = 'regenerate';
    fixture.componentInstance.syncState = 'ready';
    fixture.componentInstance.showReturnToLearn = true;
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.learn-orchestration-banner__learn-link');
    expect(link).not.toBeNull();
    expect(link.getAttribute('href')).toBe('/plans/4/learn');
    expect(link.textContent).toContain('Return to learning screen');
  });

  it('marks regenerate step complete when return to learn is clicked', () => {
    fixture.componentInstance.mode = 'regenerate';
    fixture.componentInstance.syncState = 'ready';
    fixture.componentInstance.showReturnToLearn = true;
    fixture.detectChanges();

    const link = fixture.nativeElement.querySelector('a.learn-orchestration-banner__learn-link');
    link?.click();

    expect(isLearnOrchestrationStepComplete(4, 'regenerate')).toBe(true);
    expect(readLearnOrchestrationReturnToLearn(4)).toBe(false);
  });
});
