import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import { PlanLearnLoopPhaseViewComponent } from './plan-learn-loop-phase-view.component';
import type { LearnLoopPhaseInput } from '../../domain/plans/learn-loop-phase';

const phaseInput: LearnLoopPhaseInput = {
  planId: 7,
  varianceLoaded: true,
  actionRequiredItems: [],
  stageGddProposals: [
    {
      cropId: 1,
      cropName: 'Tomato',
      stageId: 2,
      stageOrder: 1,
      stageName: 'Vegetative',
      averageGddDelta: 10,
      recordedItemCount: 2,
      currentRequiredGdd: 100,
      proposedRequiredGdd: 110
    }
  ],
  blueprintTimingProposals: [],
  hasPendingMasterUpdate: false,
  hasPostMasterPayload: false,
  carryoverSourcePlans: [],
  hasLearningSnapshot: false
};

describe('PlanLearnLoopPhaseViewComponent', () => {
  let fixture: ComponentFixture<PlanLearnLoopPhaseViewComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanLearnLoopPhaseViewComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', en as TranslationObject, true);
    translate.setDefaultLang('en');
    translate.use('en');

    fixture = TestBed.createComponent(PlanLearnLoopPhaseViewComponent);
    fixture.componentRef.setInput('planId', 7);
    fixture.componentRef.setInput('phaseInput', phaseInput);
    fixture.detectChanges();
    await fixture.whenStable();
  });

  it('renders four-phase progress bar with current phase and next action CTA', () => {
    const el: HTMLElement = fixture.nativeElement;
    expect(el.querySelector('.learn-loop-phase__progress')).toBeTruthy();
    expect(el.querySelectorAll('.learn-loop-phase__step')).toHaveLength(4);
    expect(el.textContent).toContain('Learning loop progress');
    expect(el.textContent).toContain('Observe');
    expect(el.textContent).toContain('Apply');
    expect(el.textContent).toContain('Reorganize');
    expect(el.textContent).toContain('Handover');
    expect(el.querySelector('.learn-loop-phase__step--current')).toBeTruthy();
    expect(el.querySelector('.learn-loop-phase__cta')).toBeTruthy();
    expect(el.textContent).toContain('Review stage GDD proposal');
  });
});
