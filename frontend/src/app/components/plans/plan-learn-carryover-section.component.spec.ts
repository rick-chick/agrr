import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PLAN_CARRYOVER_NEXT_PLAN_CTA_KEY } from '../../domain/plans/plan-carryover-navigation';
import { PlanLearnCarryoverSectionComponent } from './plan-learn-carryover-section.component';

describe('PlanLearnCarryoverSectionComponent', () => {
  let fixture: ComponentFixture<PlanLearnCarryoverSectionComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanLearnCarryoverSectionComponent, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.learn.carryover.title': 'Carry over learning',
        'plans.learn.carryover.hint': 'Import or create next plan',
        'plans.learn.carryover.source_label': 'Source plan',
        'plans.learn.carryover.source_hint': 'Select source',
        'plans.learn.carryover.no_source_plans': 'No source plans',
        'plans.carryover.preview.title': 'Preview',
        'plans.carryover.preview.empty': 'No preview data',
        'plans.learn.carryover.import_button': 'Import learning',
        'plans.carryover.next_plan_cta': 'Create next plan with learning',
        'plans.carryover.next_plan_hint': 'Start a new plan carrying this learning forward',
        'plans.learn.loop.handoff_source_plan': 'Source plan: {{planName}}',
        'plans.carryover.preview.stage_gdd_count': 'Stage GDD calibration proposals',
        'plans.carryover.preview.bp_timing_count': 'BP timing adjustment proposals',
        'plans.carryover.preview.bp_amount_count': 'BP amount adjustment proposals',
        'plans.learn.proposal_confidence.high': 'High confidence',
        'common.loading': 'Loading'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnCarryoverSectionComponent);
    fixture.componentInstance.planId = 7;
  });

  it('renders import controls and next-plan CTA in one section', () => {
    fixture.componentInstance.carryoverSourcePlans = [
      { id: 8, name: 'Previous', farm_id: 1 }
    ];
    fixture.componentInstance.sourcePlanName = 'Current plan';
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('#plan-learn-carryover-title')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('#plan-learn-carryover-source')).not.toBeNull();
    expect(fixture.nativeElement.textContent).toContain('Source plan: Current plan');

    const nextPlanCta = fixture.nativeElement.querySelector('.plan-learn-carryover__next-plan-cta');
    expect(nextPlanCta).not.toBeNull();
    expect(nextPlanCta.getAttribute('href')).toBe('/plans/new?carryoverFrom=7');
    expect(nextPlanCta.textContent).toContain('Create next plan with learning');
  });

  it('uses shared next-plan CTA i18n key', () => {
    fixture.detectChanges();
    expect(PLAN_CARRYOVER_NEXT_PLAN_CTA_KEY).toBe('plans.carryover.next_plan_cta');
  });

  it('emits sourcePlanChange when source select changes', () => {
    fixture.componentInstance.carryoverSourcePlans = [
      { id: 8, name: 'Previous', farm_id: 1 }
    ];
    fixture.detectChanges();

    const handler = vi.fn();
    fixture.componentInstance.sourcePlanChange.subscribe(handler);
    fixture.componentInstance.onSourcePlanChange(8);

    expect(handler).toHaveBeenCalledWith(8);
  });

  it('emits importLearning when import button clicked', () => {
    fixture.componentInstance.carryoverSourcePlans = [
      { id: 8, name: 'Previous', farm_id: 1 }
    ];
    fixture.componentInstance.selectedSourcePlanId = 8;
    fixture.componentInstance.carryoverPreview = {
      plan_id: 8,
      categories: [],
      action_required_items: [],
      unrecorded_count: 0,
      top_variance_items: []
    };
    fixture.detectChanges();

    const handler = vi.fn();
    fixture.componentInstance.importLearning.subscribe(handler);
    fixture.componentInstance.onImportLearning();

    expect(handler).toHaveBeenCalled();
  });

  it('shows proposal count rows in carryover preview table', () => {
    fixture.componentInstance.carryoverSourcePlans = [
      { id: 8, name: 'Previous', farm_id: 1 }
    ];
    fixture.componentInstance.selectedSourcePlanId = 8;
    fixture.componentInstance.carryoverPreview = {
      plan_id: 8,
      categories: [
        {
          category: 'task',
          average_delta_days: 1,
          item_count: 2,
          recorded_count: 2
        }
      ],
      stage_gdd_calibration_proposals: [{ crop_id: 1, stage_id: 2 } as never],
      blueprint_timing_adjustment_proposals: [{ crop_id: 1, category: 'general' } as never],
      action_required_items: [],
      unrecorded_count: 0,
      top_variance_items: []
    } as typeof fixture.componentInstance.carryoverPreview;
    fixture.detectChanges();

    const rows = fixture.nativeElement.querySelectorAll('.plan-carryover-preview__table tbody tr');
    expect(rows).toHaveLength(3);
    expect(rows[1].textContent).toContain('Stage GDD calibration proposals');
    expect(rows[1].textContent).toContain('1');
    expect(rows[2].textContent).toContain('BP timing adjustment proposals');
  });
});
