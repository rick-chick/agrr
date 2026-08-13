import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanLearnLoopProgressComponent } from './plan-learn-loop-progress.component';

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
        'plans.learn.loop.next_action.handoff_carryover': 'Import carryover'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnLoopProgressComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders all four loop phases with observe highlighted when action items exist', () => {
    fixture.componentInstance.actionRequiredItems = [{ field_cultivation_id: 100 }];
    fixture.detectChanges();

    const phases = fixture.nativeElement.querySelectorAll('.learn-loop-progress__phase');
    expect(phases).toHaveLength(4);
    expect(phases[0].classList.contains('learn-loop-progress__phase--current')).toBe(true);
    expect(phases[0].getAttribute('aria-current')).toBe('step');
  });

  it('shows workbench router link CTA for observe phase with field cultivation', () => {
    fixture.componentInstance.actionRequiredItems = [{ field_cultivation_id: 100 }];
    fixture.detectChanges();

    const cta = fixture.nativeElement.querySelector('.learn-loop-progress__next-cta');
    expect(cta).not.toBeNull();
    expect(cta.getAttribute('href')).toBe('/plans/7?field_cultivation_id=100');
    expect(cta.textContent).toContain('Open workbench');
  });

  it('shows carryover scroll CTA when proposals are applied and snapshot exists', () => {
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
    fixture.componentInstance.hasLearningSnapshot = true;
    fixture.componentInstance.carryoverSourcePlanCount = 1;
    fixture.detectChanges();

    const completedPhases = fixture.nativeElement.querySelectorAll(
      '.learn-loop-progress__phase--completed'
    );
    expect(completedPhases.length).toBeGreaterThan(0);
  });
});
