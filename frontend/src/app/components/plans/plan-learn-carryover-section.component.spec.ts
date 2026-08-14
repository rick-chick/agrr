import { ComponentFixture, TestBed } from '@angular/core/testing';
import { FormsModule } from '@angular/forms';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { PlanLearnCarryoverSectionComponent } from './plan-learn-carryover-section.component';

const sourcePlans: PlanSummary[] = [
  { id: 8, name: 'Previous', status: 'active', farm_id: 3 }
];

const preview: PlanVsActualSummary = {
  plan_id: 8,
  unrecorded_count: 0,
  categories: [{ category: 'general', average_delta_days: 2, item_count: 1, recorded_count: 1 }],
  top_variance_items: []
};

describe('PlanLearnCarryoverSectionComponent', () => {
  let fixture: ComponentFixture<PlanLearnCarryoverSectionComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanLearnCarryoverSectionComponent, FormsModule, TranslateModule.forRoot()],
      providers: [provideRouter([])]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.carryover.section_title': 'Learning handoff',
        'plans.carryover.import_title': 'Import learning from another plan',
        'plans.carryover.import_hint': 'Copy variance learning from a previous plan.',
        'plans.carryover.next_plan_hint': 'Create a new plan with this plan learning.',
        'plans.carryover.next_plan_cta': 'Create next plan with learning',
        'plans.carryover.source_label': 'Source plan',
        'plans.carryover.source_hint': 'Select a previous plan',
        'plans.carryover.no_source_plans': 'No other plans available.',
        'plans.carryover.preview_title': 'Learning data preview',
        'plans.carryover.preview_empty': 'No category variance data.',
        'plans.carryover.import_button': 'Import learning',
        'plans.task_schedules.variance_subview.category_column': 'Category',
        'plans.task_schedules.variance_subview.category_average': 'Average',
        'plans.task_schedules.variance_subview.not_available': 'N/A',
        'plans.task_schedules.variance_subview.average_value': 'Avg {{delta}}',
        'common.loading': 'Loading'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnCarryoverSectionComponent);
    fixture.componentInstance.planId = 7;
    fixture.componentInstance.carryoverSourcePlans = sourcePlans;
    fixture.componentInstance.showNextPlanCta = true;
  });

  it('renders import and next-plan CTA in one section', () => {
    fixture.detectChanges();

    const section = fixture.nativeElement.querySelector('#plan-learn-carryover-title');
    expect(section).toBeTruthy();
    expect(section.textContent).toContain('Learning handoff');
    expect(fixture.nativeElement.querySelector('#plan-learn-carryover-source')).toBeTruthy();
    expect(fixture.nativeElement.querySelector('.plan-learn-carryover__next-plan-cta')).toBeTruthy();
  });

  it('links next-plan CTA to plan-new with carryoverFrom query param', () => {
    fixture.detectChanges();

    const cta = fixture.nativeElement.querySelector(
      '.plan-learn-carryover__next-plan-cta'
    ) as HTMLAnchorElement;
    expect(cta.getAttribute('href')).toBe('/plans/new?carryoverFrom=7');
    expect(cta.textContent).toContain('Create next plan with learning');
  });

  it('hides next-plan CTA when showNextPlanCta is false', () => {
    fixture.componentInstance.showNextPlanCta = false;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.plan-learn-carryover__next-plan-cta')).toBeNull();
  });

  it('shows not available when category average is null', () => {
    fixture.componentInstance.selectedSourcePlanId = 8;
    fixture.componentInstance.carryoverPreview = {
      ...preview,
      categories: [{ category: 'general', average_delta_days: null, item_count: 1, recorded_count: 0 }]
    };
    fixture.detectChanges();

    const cell = fixture.nativeElement.querySelector(
      '.plan-learn-carryover-preview__table tbody td:last-child'
    );
    expect(cell?.textContent).toContain('N/A');
  });

  it('emits importLearning when import button is clicked', () => {
    fixture.componentInstance.selectedSourcePlanId = 8;
    fixture.componentInstance.carryoverPreview = preview;
    fixture.detectChanges();

    const importSpy = vi.fn();
    fixture.componentInstance.importLearning.subscribe(importSpy);

    const button = fixture.nativeElement.querySelector(
      '.plan-learn-carryover__import-button'
    ) as HTMLButtonElement;
    button.click();

    expect(importSpy).toHaveBeenCalled();
  });
});
