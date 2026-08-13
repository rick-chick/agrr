import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';
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
        'plans.learn.loop.next_action.observe_workbench': 'Open workbench',
        'plans.learn.loop.next_action.handoff_new_plan': 'Create next plan (carry over learning)'
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
    expect(phases).toHaveLength(4);
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

  it('shows new-plan carryover router link CTA when learning snapshot and carryover sources exist', () => {
    fixture.componentInstance.hasLearningSnapshot = true;
    fixture.componentInstance.carryoverSourcePlanCount = 2;
    fixture.detectChanges();

    const currentPhase = fixture.nativeElement.querySelector(
      '.learn-loop-progress__phase--current .learn-loop-progress__phase-label'
    );
    expect(currentPhase?.textContent).toContain('Handoff');

    const cta = fixture.nativeElement.querySelector('.learn-loop-progress__next-cta');
    expect(cta?.getAttribute('href')).toBe('/plans/new?carryoverFrom=7');
    expect(cta?.textContent).toContain('Create next plan');
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
});
