import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import {
  clearLearnOrchestrationProgressCache,
  hydrateLearnOrchestrationProgress
} from '../../domain/plans/learn-master-update-orchestration';
import {
  PlanLearnMasterUpdateNextStepsComponent,
  buildLearnMasterUpdateNextSteps
} from './plan-learn-master-update-next-steps.component';

describe('buildLearnMasterUpdateNextSteps', () => {
  it('builds three steps with learningOrchestration query params', () => {
    const steps = buildLearnMasterUpdateNextSteps(7);
    expect(steps).toHaveLength(3);
    expect(steps[0]).toMatchObject({
      stepKey: 'placement',
      commands: ['/plans', 7],
      queryParams: { learningOrchestration: 'adjust' }
    });
    expect(steps[1]).toMatchObject({
      stepKey: 'regenerate',
      commands: ['/plans', 7, 'task_schedule'],
      queryParams: { learningOrchestration: 'regenerate' }
    });
    expect(steps[2]).toMatchObject({
      stepKey: 'sync_verify',
      commands: ['/plans', 7, 'task_schedule'],
      queryParams: { learningOrchestration: 'sync_verify' }
    });
  });
});

describe('PlanLearnMasterUpdateNextStepsComponent', () => {
  let fixture: ComponentFixture<PlanLearnMasterUpdateNextStepsComponent>;

  beforeEach(async () => {
    clearLearnOrchestrationProgressCache();
    await TestBed.configureTestingModule({
      imports: [PlanLearnMasterUpdateNextStepsComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.learn.next_steps.title': 'Next steps after master update',
        'plans.learn.next_steps.lead': 'Follow these steps to refresh your plan.',
        'plans.learn.next_steps.step_label.1': 'Step 1',
        'plans.learn.next_steps.step_label.2': 'Step 2',
        'plans.learn.next_steps.step_label.3': 'Step 3',
        'plans.learn.next_steps.placement.title': 'Verify placement',
        'plans.learn.next_steps.placement.description': 'Re-optimize after master changes.',
        'plans.learn.next_steps.regenerate.title': 'Regenerate task schedule',
        'plans.learn.next_steps.regenerate.description': 'Rebuild the work schedule.',
        'plans.learn.next_steps.sync_verify.title': 'Verify sync',
        'plans.learn.next_steps.sync_verify.description': 'Confirm task schedule sync.',
        'plans.learn.next_steps.cta.placement': 'Open workbench',
        'plans.learn.next_steps.cta.regenerate': 'Open task schedule',
        'plans.learn.next_steps.cta.sync_verify': 'Check sync',
        'plans.learn.next_steps.completed': 'Completed',
        'plans.learn.next_steps.continue': 'Continue'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnMasterUpdateNextStepsComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders checklist links when visible', () => {
    fixture.componentInstance.visible = true;
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent;
    expect(text).toContain('Next steps after master update');
    expect(text).toContain('Verify placement');
    expect(text).toContain('Regenerate task schedule');

    const links = fixture.nativeElement.querySelectorAll('a.learn-next-steps__cta');
    expect(links).toHaveLength(3);
    expect(links[0].getAttribute('href')).toBe('/plans/7?learningOrchestration=adjust');
    expect(links[1].getAttribute('href')).toBe(
      '/plans/7/task_schedule?learningOrchestration=regenerate'
    );
    expect(links[2].getAttribute('href')).toBe(
      '/plans/7/task_schedule?learningOrchestration=sync_verify'
    );
  });

  it('renders continue link to the first incomplete step', () => {
    hydrateLearnOrchestrationProgress(7, { placement: true });

    fixture.componentInstance.visible = true;
    fixture.detectChanges();

    const continueLink = fixture.nativeElement.querySelector('a.learn-next-steps__continue');
    expect(continueLink).not.toBeNull();
    expect(continueLink.getAttribute('href')).toBe(
      '/plans/7/task_schedule?learningOrchestration=regenerate'
    );
    expect(continueLink.textContent).toContain('Continue');
  });

  it('does not render when not visible', () => {
    fixture.componentInstance.visible = false;
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.learn-next-steps')).toBeNull();
  });

  it('marks regenerate and sync_verify steps as completed from hydrated progress', () => {
    hydrateLearnOrchestrationProgress(7, { regenerate: true, sync_verify: true });

    fixture.componentInstance.visible = true;
    fixture.detectChanges();

    const completedItems = fixture.nativeElement.querySelectorAll('.learn-next-steps__item--completed');
    expect(completedItems).toHaveLength(2);
    expect(completedItems[0].textContent).toContain('Completed');
    expect(completedItems[1].textContent).toContain('Completed');
    expect(completedItems[0].querySelector('a.learn-next-steps__cta')).toBeNull();
  });
});
