import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { beforeEach, describe, expect, it } from 'vitest';
import { PlanLearnAmountGroupSummariesComponent } from './plan-learn-amount-group-summaries.component';
import type { PlanVsActualAmountGroupSummary } from '../../domain/plans/plan-vs-actual-summary';

const summaries: PlanVsActualAmountGroupSummary[] = [
  {
    category: 'fertilizer',
    stage_order: 1,
    stage_name: 'Vegetative',
    task_type: 'fertilize',
    average_amount_delta: 0.5,
    recorded_item_count: 2,
    amount_unit: 'kg'
  },
  {
    category: 'pest_control',
    stage_order: 2,
    stage_name: 'Fruiting',
    task_type: 'preventive_spray',
    average_amount_delta: -0.2,
    recorded_item_count: 1,
    amount_unit: 'L'
  }
];

describe('PlanLearnAmountGroupSummariesComponent', () => {
  let fixture: ComponentFixture<PlanLearnAmountGroupSummariesComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanLearnAmountGroupSummariesComponent, TranslateModule.forRoot()],
    }).compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setDefaultLang('en');
    translate.use('en');
    translate.setTranslation(
      'en',
      {
        'plans.learn.amount_group_summaries.title': 'Stage amount summaries',
        'plans.learn.amount_group_summaries.lead':
          'Amount variance grouped by crop stage, category, and task type.',
        'plans.learn.amount_group_summaries.empty': 'No amount summaries yet.',
        'plans.learn.amount_group_summaries.stage_column': 'Stage',
        'plans.learn.amount_group_summaries.category_column': 'Category',
        'plans.learn.amount_group_summaries.task_type_column': 'Task type',
        'plans.learn.amount_group_summaries.delta_column': 'Average delta',
        'plans.learn.amount_group_summaries.recorded_column': 'Recorded',
        'plans.learn.amount_group_summaries.view_proposal': 'View proposal',
        'plans.learn.amount_group_summaries.stage_label': 'Stage {{order}} — {{name}}',
        'plans.learn.amount_group_summaries.stage_unassigned': 'Unassigned stage',
        'plans.learn.bp_amount_adjustment.category.fertilizer': 'Fertilization',
        'plans.learn.bp_amount_adjustment.category.pest_control': 'Pest control',
        'plans.learn.bp_amount_adjustment.task_type.fertilize': 'Fertilize',
        'plans.learn.bp_amount_adjustment.task_type.preventive_spray': 'Preventive spray',
        'common.loading': 'Loading'
      },
      true
    );

    fixture = TestBed.createComponent(PlanLearnAmountGroupSummariesComponent);
  });

  it('renders amount_group_summaries rows with stage_order and delta', () => {
    fixture.componentInstance.summaries = summaries;
    fixture.detectChanges();

    const text = fixture.nativeElement.textContent ?? '';
    expect(text).toContain('Stage amount summaries');
    expect(text).toContain('Vegetative');
    expect(text).toContain('Fertilization');
    expect(text).toContain('Fertilize');
    expect(text).toContain('+0.5 kg');
    expect(text).toContain('Fruiting');
    expect(text).toContain('Pest control');
    expect(text).toContain('-0.2 L');
  });

  it('links each summary row to the matching bp_amount proposal anchor by stage_order', () => {
    fixture.componentInstance.summaries = summaries;
    fixture.detectChanges();

    const links = Array.from(
      fixture.nativeElement.querySelectorAll('.plan-learn-amount-group-summaries__proposal-link')
    ) as HTMLAnchorElement[];

    expect(links).toHaveLength(2);
    expect(links[0]?.getAttribute('href')).toBe(
      '#plan-learn-bp-amount-proposal-1-fertilizer-fertilize'
    );
    expect(links[1]?.getAttribute('href')).toBe(
      '#plan-learn-bp-amount-proposal-2-pest_control-preventive_spray'
    );
  });

  it('shows empty state when summaries are absent', () => {
    fixture.componentInstance.summaries = [];
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('No amount summaries yet.');
    expect(fixture.nativeElement.querySelector('table')).toBeNull();
  });
});
