import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';
import {
  markAllConfirmedProposalsDone,
  markLearnProposalConfirmed,
  markStageGddProposalAppliedPending,
  stageGddProposalProgressKey
} from '../../domain/plans/learn-proposal-application-progress';
import { PlanLearnLoopProgressComponent } from './plan-learn-loop-progress.component';

function actionItem(fieldCultivationId: number): PlanVarianceActionItem {
  return {
    item_id: 1,
    field_cultivation_id: fieldCultivationId,
    category: 'task',
    name: 'Irrigation',
    scheduled_date: '2026-06-01',
    actual_date: '2026-06-03',
    delta_days: 2,
    gdd_trigger: 100,
    gdd_at_actual: 110,
    gdd_delta: 10,
    exceedance_kind: 'days'
  };
}

describe('PlanLearnLoopProgressComponent', () => {
  let fixture: ComponentFixture<PlanLearnLoopProgressComponent>;

  beforeEach(async () => {
    sessionStorage.clear();
    await TestBed.configureTestingModule({
      imports: [PlanLearnLoopProgressComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.learn.loop.title': 'Learn loop progress',
        'plans.learn.loop.next_action_title': 'Next action',
        'plans.learn.loop.phase.observe': 'Observe',
        'plans.learn.loop.phase.apply': 'Apply',
        'plans.learn.loop.phase.reorganize': 'Reorganize',
        'plans.learn.loop.phase.handoff': 'Handoff',
        'plans.learn.loop.phase.complete': 'Complete',
        'plans.learn.loop.complete_message': 'Learning loop complete',
        'plans.learn.loop.next_action.observe_workbench': 'Open workbench',
        'plans.learn.loop.next_action.handoff_carryover': 'Import carryover',
        'plans.learn.loop.next_action.complete_reorganize': 'Verify placement',
        'plans.learn.loop.next_action.complete_next_plan': 'Go to plans'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnLoopProgressComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders all four loop phases with observe highlighted when action items exist', () => {
    fixture.componentInstance.actionRequiredItems = [actionItem(100)];
    fixture.detectChanges();

    const phases = fixture.nativeElement.querySelectorAll('.learn-loop-progress__phase');
    expect(phases).toHaveLength(5);
    expect(phases[0].classList.contains('learn-loop-progress__phase--current')).toBe(true);
    expect(phases[0].getAttribute('aria-current')).toBe('step');
  });

  it('shows workbench router link CTA for observe phase with field cultivation', () => {
    fixture.componentInstance.actionRequiredItems = [actionItem(100)];
    fixture.detectChanges();

    const cta = fixture.nativeElement.querySelector('.learn-loop-progress__next-cta');
    expect(cta).not.toBeNull();
    expect(cta.getAttribute('href')).toBe('/plans/7?field_cultivation_id=100');
    expect(cta.textContent).toContain('Open workbench');
  });

  it('shows carryover scroll CTA when learning snapshot and carryover sources exist', () => {
    fixture.componentInstance.hasLearningSnapshot = true;
    fixture.componentInstance.carryoverSourcePlanCount = 2;
    fixture.detectChanges();

    const currentPhase = fixture.nativeElement.querySelector(
      '.learn-loop-progress__phase--current .learn-loop-progress__phase-label'
    );
    expect(currentPhase?.textContent).toContain('Handoff');

    const cta = fixture.nativeElement.querySelector('.learn-loop-progress__next-cta');
    expect(cta?.getAttribute('href')).toBe('#plan-learn-carryover-title');
    expect(cta?.textContent).toContain('Import carryover');
  });

  it('marks earlier phases as completed when current phase is handoff', () => {
    fixture.componentInstance.hasLearningSnapshot = true;
    fixture.componentInstance.carryoverSourcePlanCount = 1;
    fixture.detectChanges();

    const completedPhases = fixture.nativeElement.querySelectorAll(
      '.learn-loop-progress__phase--completed'
    );
    expect(completedPhases.length).toBeGreaterThan(0);
  });

  it('shows learning loop complete with reorganize and plans CTAs when all proposals are resolved', () => {
    const key = stageGddProposalProgressKey(1, 2);
    markStageGddProposalAppliedPending(7, { cropId: 1, stageId: 2 });
    markLearnProposalConfirmed(7, key);
    markAllConfirmedProposalsDone(7);

    fixture.componentInstance.stageGddProposals = [
      {
        cropId: 1,
        cropName: 'Tomato',
        stageId: 2,
        stageOrder: 1,
        stageName: 'Vegetative',
        averageGddDelta: 10,
        recordedItemCount: 3,
        currentRequiredGdd: 100,
        proposedRequiredGdd: 110
      }
    ];
    fixture.componentInstance.progressRevision = 1;
    fixture.detectChanges();

    expect(
      fixture.nativeElement.querySelector('.learn-loop-progress__complete-message')?.textContent
    ).toContain('Learning loop complete');

    const primaryCta = fixture.nativeElement.querySelector('.learn-loop-progress__next-cta');
    expect(primaryCta?.getAttribute('href')).toBe('/plans/7?learningOrchestration=adjust');
    expect(primaryCta?.textContent).toContain('Verify placement');

    const secondaryCta = fixture.nativeElement.querySelector(
      '.learn-loop-progress__secondary-cta'
    );
    expect(secondaryCta?.getAttribute('href')).toBe('/plans');
    expect(secondaryCta?.textContent).toContain('Go to plans');
  });
});
