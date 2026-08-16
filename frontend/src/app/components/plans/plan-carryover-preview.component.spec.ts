import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanCarryoverPreviewComponent } from './plan-carryover-preview.component';

describe('PlanCarryoverPreviewComponent', () => {
  let fixture: ComponentFixture<PlanCarryoverPreviewComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanCarryoverPreviewComponent, TranslateModule.forRoot()]
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.carryover.preview.title': 'Learning data preview',
        'plans.carryover.preview.empty': 'No category variance data.',
        'plans.carryover.preview.stage_gdd_count': 'Stage GDD calibration proposals',
        'plans.task_schedules.variance_subview.category_column': 'Category',
        'plans.task_schedules.variance_subview.category_average': 'Avg Δ days',
        'plans.task_schedules.variance_subview.not_available': '—',
        'plans.task_schedules.variance_subview.average_value': '{{delta}} days',
        'plans.task_schedules.variance_subview.category.general': 'General tasks',
        'plans.learn.proposal_confidence.low': 'Low confidence',
        'plans.learn.proposal_confidence.high': 'High confidence'
      },
      true
    );

    fixture = TestBed.createComponent(PlanCarryoverPreviewComponent);
  });

  it('renders shared preview table with proposal counts and confidence badge', () => {
    fixture.componentRef.setInput('summary', {
      plan_id: 8,
      unrecorded_count: 2,
      categories: [
        {
          category: 'general',
          average_delta_days: 2,
          item_count: 1,
          recorded_count: 1
        }
      ],
      stage_gdd_calibration_proposals: [{ crop_id: 1, stage_id: 2 } as never],
      action_required_items: [],
      top_variance_items: []
    });
    fixture.detectChanges();

    const root = fixture.nativeElement.querySelector('.plan-carryover-preview');
    expect(root).not.toBeNull();
    expect(fixture.nativeElement.textContent).toContain('Learning data preview');
    expect(fixture.nativeElement.textContent).toContain('Low confidence');
    expect(fixture.nativeElement.textContent).toContain('General tasks');
    expect(fixture.nativeElement.textContent).toContain('Stage GDD calibration proposals');

    const rows = fixture.nativeElement.querySelectorAll('.plan-carryover-preview__table tbody tr');
    expect(rows).toHaveLength(2);
  });

  it('shows empty hint when summary has no table rows', () => {
    fixture.componentRef.setInput('summary', {
      plan_id: 8,
      unrecorded_count: 0,
      categories: [],
      top_variance_items: []
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('No category variance data.');
    expect(fixture.nativeElement.querySelector('.plan-carryover-preview__table')).toBeNull();
    expect(fixture.nativeElement.textContent).toContain('High confidence');
  });
});
